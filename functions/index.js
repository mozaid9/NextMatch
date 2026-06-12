/**
 * NextMatch backend: push notification fan-out + Stripe payments.
 *
 * These functions run with admin privileges (they bypass Firestore security
 * rules). Stripe checkout/fulfilment lives here so the client never decides
 * what to charge and never writes real payment records — see SECURITY.md.
 */
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const Stripe = require('stripe');

initializeApp();

const REGION = 'europe-west2'; // London — closest to the user base.

// Set via: firebase functions:secrets:set STRIPE_SECRET_KEY (sk_test_... for
// test mode) and STRIPE_WEBHOOK_SECRET (whsec_... from the webhook endpoint).
const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');

// THE fee. One place to change it. Mirrored for display only in
// lib/core/utils/currency_helpers.dart — keep the two in sync.
const SERVICE_FEE_RATE = 0.06;
const SERVICE_FEE_MIN_PENCE = 50;

function serviceFeePence(amountPence) {
  return Math.max(Math.round(amountPence * SERVICE_FEE_RATE), SERVICE_FEE_MIN_PENCE);
}

// Stripe Checkout may only bounce players back to origins we run.
const ALLOWED_RETURN_ORIGINS = new Set([
  'http://localhost:8080', // local dev server
  'https://nextmatch-eb038.web.app', // Firebase Hosting (future deploy)
  'https://nextmatch-eb038.firebaseapp.com',
]);

function isAllowedReturnUrl(url) {
  try {
    return ALLOWED_RETURN_ORIGINS.has(new URL(url).origin);
  } catch (error) {
    return false;
  }
}

/** Fetch a user's registered device tokens. */
async function tokensFor(uid) {
  const snapshot = await getFirestore()
    .collection('users')
    .doc(uid)
    .collection('fcmTokens')
    .get();
  return snapshot.docs.map((doc) => doc.id);
}

/**
 * Record the notification in the user's in-app feed (the bell icon).
 * This always happens, even when no device tokens exist — the feed is
 * the "in case you missed it" backstop for pushes.
 */
async function recordInAppNotification(uid, { title, body, data = {} }) {
  await getFirestore()
    .collection('users')
    .doc(uid)
    .collection('notifications')
    .add({
      title,
      body,
      type: data.type || 'general',
      matchId: data.matchId || null,
      chatId: data.chatId || null,
      read: false,
      createdAt: new Date(),
    });
}

/**
 * Send a notification to every device a user has registered, pruning
 * tokens FCM reports as dead so the list stays clean. Also records the
 * notification in the user's in-app feed.
 */
async function pushToUser(uid, { title, body, data = {} }) {
  await recordInAppNotification(uid, { title, body, data });

  const tokens = await tokensFor(uid);
  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });

  const dead = [];
  response.responses.forEach((result, index) => {
    const code = result.error?.code || '';
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    ) {
      dead.push(tokens[index]);
    }
  });
  if (dead.length > 0) {
    const batch = getFirestore().batch();
    for (const token of dead) {
      batch.delete(
        getFirestore()
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token),
      );
    }
    await batch.commit();
  }
}

function formatKickOff(timestamp) {
  if (!timestamp || typeof timestamp.toDate !== 'function') return '';
  const date = timestamp.toDate();
  return new Intl.DateTimeFormat('en-GB', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'Europe/London',
  }).format(date);
}

/** Match invite lands in a player's inbox → tell them. */
exports.onMatchInviteCreated = onDocumentCreated(
  { document: 'users/{uid}/matchInvites/{matchId}', region: REGION },
  async (event) => {
    const invite = event.data?.data();
    if (!invite) return;

    const inviter = invite.inviterName || 'A friend';
    const title = `${inviter} invited you to a match`;
    const kickOff = formatKickOff(invite.matchDateTime);
    const matchTitle = invite.matchTitle || 'a game';
    const body = kickOff
      ? `${matchTitle} · ${kickOff}. Accept in the app to secure your spot.`
      : `${matchTitle}. Accept in the app to secure your spot.`;

    await pushToUser(event.params.uid, {
      title,
      body,
      data: { type: 'matchInvite', matchId: event.params.matchId },
    });
  },
);

/** New DM → tell the other participant. */
exports.onChatMessageCreated = onDocumentCreated(
  { document: 'chats/{chatId}/messages/{messageId}', region: REGION },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const chatSnapshot = await getFirestore()
      .collection('chats')
      .doc(event.params.chatId)
      .get();
    const chat = chatSnapshot.data();
    if (!chat) return;

    const participantIds = chat.participantIds || [];
    const senderIndex = participantIds.indexOf(message.senderUid);
    if (senderIndex === -1) return;
    const recipientUid = participantIds.find((id) => id !== message.senderUid);
    if (!recipientUid) return;

    const names = chat.participantNames || [];
    const senderName = names[senderIndex] || 'New message';
    const body = (message.body || '').slice(0, 140);

    await pushToUser(recipientUid, {
      title: senderName,
      body,
      data: { type: 'chatMessage', chatId: event.params.chatId },
    });
  },
);

/**
 * Refund every Succeeded Stripe payment matching the filters. Each payment
 * doc is claimed (Succeeded → RefundPending) in a transaction first, so a
 * retried trigger can't refund the same charge twice.
 */
async function refundStripePayments({ matchId, userId = null }) {
  const db = getFirestore();
  let query = db
    .collection('payments')
    .where('matchId', '==', matchId)
    .where('paymentProvider', '==', 'stripe')
    .where('status', '==', 'Succeeded');
  if (userId) query = query.where('userId', '==', userId);
  const snapshot = await query.get();

  const stripe = new Stripe(stripeSecretKey.value());
  const refunded = [];
  for (const doc of snapshot.docs) {
    const payment = doc.data();
    if (!payment.stripePaymentIntentId) continue;

    const claimed = await db.runTransaction(async (transaction) => {
      const fresh = await transaction.get(doc.ref);
      if (fresh.data()?.status !== 'Succeeded') return false;
      transaction.update(doc.ref, { status: 'RefundPending' });
      return true;
    });
    if (!claimed) continue;

    try {
      await stripe.refunds.create({
        payment_intent: payment.stripePaymentIntentId,
      });
      await doc.ref.update({ status: 'Refunded', refundedAt: new Date() });
      refunded.push(payment.userId);
    } catch (error) {
      // Already-refunded intents land here on webhook/trigger replays —
      // record the state rather than leaving the doc stuck in RefundPending.
      const alreadyRefunded = error?.code === 'charge_already_refunded';
      await doc.ref.update({
        status: alreadyRefunded ? 'Refunded' : 'RefundFailed',
        refundError: alreadyRefunded ? null : String(error.message || error),
      });
      if (alreadyRefunded) refunded.push(payment.userId);
    }
  }
  return refunded;
}

/**
 * Organiser cancels a match → tell everyone still holding a spot, and
 * refund every Stripe payment on the match in full.
 */
exports.onMatchCancelled = onDocumentUpdated(
  {
    document: 'matches/{matchId}',
    region: REGION,
    secrets: [stripeSecretKey],
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === 'Cancelled' || after.status !== 'Cancelled') return;

    const participants = await getFirestore()
      .collection('matches')
      .doc(event.params.matchId)
      .collection('participants')
      .get();

    const activeStatuses = new Set([
      'Joined',
      'PendingPayment',
      'PendingApproval',
    ]);
    const reason = after.cancelReason ? ` Reason: ${after.cancelReason}` : '';
    const title = `${after.title || 'Your match'} is cancelled`;
    const body = `The organiser cancelled the game.${reason}`;

    await Promise.all(
      participants.docs
        .filter((doc) => activeStatuses.has(doc.data().attendanceStatus))
        .map((doc) =>
          pushToUser(doc.id, {
            title,
            body,
            data: { type: 'matchCancelled', matchId: event.params.matchId },
          }),
        ),
    );

    const refundedUids = await refundStripePayments({
      matchId: event.params.matchId,
    });
    await Promise.all(
      refundedUids.map((uid) =>
        pushToUser(uid, {
          title: 'Your payment is being refunded',
          body: `${after.title || 'The match'} was cancelled, so your full payment is on its way back to your card.`,
          data: { type: 'paymentRefunded', matchId: event.params.matchId },
        }),
      ),
    );
  },
);

/**
 * Player withdraws from a match they had paid for. Early withdrawals
 * (more than 24h before kick-off, status 'Cancelled') are refunded in
 * full; late ones ('LateCancelled') are not refunded automatically —
 * matching the reliability tiers the app already applies.
 */
exports.onParticipantWithdrew = onDocumentUpdated(
  {
    document: 'matches/{matchId}/participants/{uid}',
    region: REGION,
    secrets: [stripeSecretKey],
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const wasIn = before.attendanceStatus === 'Joined';
    const withdrew =
      after.attendanceStatus === 'Cancelled' ||
      after.attendanceStatus === 'LateCancelled';
    if (!wasIn || !withdrew) return;
    if (!(before.amountPaid > 0)) return;

    const { matchId, uid } = event.params;
    if (after.attendanceStatus === 'LateCancelled') {
      await pushToUser(uid, {
        title: 'Withdrawal confirmed — no automatic refund',
        body: 'You withdrew within 24 hours of kick-off, so your payment stays with the match. Speak to the organiser if there are special circumstances.',
        data: { type: 'withdrawalNoRefund', matchId },
      });
      return;
    }

    const refundedUids = await refundStripePayments({ matchId, userId: uid });
    if (refundedUids.length > 0) {
      await pushToUser(uid, {
        title: 'Refund on its way',
        body: 'You withdrew in good time, so your payment is being refunded in full.',
        data: { type: 'paymentRefunded', matchId },
      });
    }
  },
);

/** Organiser approves a pending join request → prompt the player to pay. */
exports.onParticipantApproved = onDocumentUpdated(
  { document: 'matches/{matchId}/participants/{uid}', region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.organiserApproved === true || after.organiserApproved !== true) {
      return;
    }

    const matchSnapshot = await getFirestore()
      .collection('matches')
      .doc(event.params.matchId)
      .get();
    const match = matchSnapshot.data() || {};
    const isSplit = match.paymentMode === 'Split';

    await pushToUser(event.params.uid, {
      title: `You're approved for ${match.title || 'the match'}`,
      body: isSplit
        ? 'Pay within 24 hours to lock in your spot.'
        : "You're in — see the match for details.",
      data: { type: 'participantApproved', matchId: event.params.matchId },
    });
  },
);

// ---------------------------------------------------------------------------
// Stripe payments
// ---------------------------------------------------------------------------

const CONFIRMED_STATUSES = new Set(['Joined', 'Attended', 'NoShow']);
const DEAD_STATUSES = new Set(['Rejected', 'Cancelled', 'LateCancelled']);

/**
 * Create a Stripe Checkout session for a match share. The amount is computed
 * here from the match document — the client only says WHICH match, never how
 * much to pay.
 */
exports.createStripeCheckout = onCall(
  { region: REGION, secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to pay for a match.');
    }
    const uid = request.auth.uid;
    const { matchId, successUrl, cancelUrl } = request.data || {};
    const position =
      typeof request.data?.position === 'string' && request.data.position
        ? request.data.position
        : 'Any';
    if (typeof matchId !== 'string' || matchId === '') {
      throw new HttpsError('invalid-argument', 'matchId is required.');
    }
    for (const url of [successUrl, cancelUrl]) {
      if (typeof url !== 'string' || !isAllowedReturnUrl(url)) {
        throw new HttpsError('invalid-argument', 'Return URL origin not allowed.');
      }
    }

    const db = getFirestore();
    const matchSnapshot = await db.collection('matches').doc(matchId).get();
    if (!matchSnapshot.exists) {
      throw new HttpsError('not-found', 'Match no longer exists.');
    }
    const match = matchSnapshot.data();
    if (match.status === 'Cancelled' || match.status === 'Completed') {
      throw new HttpsError('failed-precondition', 'This match is no longer open.');
    }
    if ((match.joinedPlayerCount || 0) >= (match.totalPlayersNeeded || 0)) {
      throw new HttpsError('failed-precondition', 'This match is already full.');
    }
    if (match.paymentMode !== 'Split') {
      throw new HttpsError('failed-precondition', 'This match is not paid per player.');
    }
    const price = Number(match.pricePerPlayer);
    if (!Number.isFinite(price) || price <= 0) {
      throw new HttpsError('failed-precondition', 'This match has no per-player price.');
    }

    const participantSnapshot = await matchSnapshot.ref
      .collection('participants')
      .doc(uid)
      .get();
    if (participantSnapshot.exists) {
      const participant = participantSnapshot.data();
      if (CONFIRMED_STATUSES.has(participant.attendanceStatus)) {
        throw new HttpsError('failed-precondition', 'You are already in this match.');
      }
      if (DEAD_STATUSES.has(participant.attendanceStatus)) {
        throw new HttpsError('failed-precondition', 'This match request is no longer active.');
      }
      if (
        participant.attendanceStatus === 'PendingApproval' &&
        participant.organiserApproved !== true
      ) {
        throw new HttpsError('failed-precondition', 'This spot still needs organiser approval.');
      }
    }

    const amountPence = Math.round(price * 100);
    const feePence = serviceFeePence(amountPence);

    const stripe = new Stripe(stripeSecretKey.value());
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: 'gbp',
            unit_amount: amountPence,
            product_data: { name: `Match share — ${match.title || 'Football match'}` },
          },
        },
        {
          quantity: 1,
          price_data: {
            currency: 'gbp',
            unit_amount: feePence,
            product_data: { name: 'NextMatch service fee' },
          },
        },
      ],
      customer_email: request.auth.token.email || undefined,
      metadata: {
        matchId,
        uid,
        position,
        amountPence: String(amountPence),
        feePence: String(feePence),
      },
      payment_intent_data: { metadata: { matchId, uid } },
      success_url: successUrl,
      cancel_url: cancelUrl,
    });

    return { url: session.url };
  },
);

/**
 * Fulfil a completed checkout: write the payment record, confirm the
 * participant, bump the match counter — all server-side, idempotent on the
 * session id. If the match filled up or was cancelled while the player was
 * on Stripe's page, the payment is refunded in full instead.
 */
async function fulfilCheckout(stripe, session) {
  const { matchId, uid, position } = session.metadata || {};
  if (!matchId || !uid) return;

  const db = getFirestore();
  const paymentRef = db.collection('payments').doc(session.id);
  const matchRef = db.collection('matches').doc(matchId);
  const participantRef = matchRef.collection('participants').doc(uid);
  const joinedRef = db
    .collection('users')
    .doc(uid)
    .collection('joinedMatches')
    .doc(matchId);
  const userRef = db.collection('users').doc(uid);

  const total = (session.amount_total || 0) / 100;
  const fee = Number(session.metadata?.feePence || 0) / 100;
  const amount = total - fee;

  const outcome = await db.runTransaction(async (transaction) => {
    const paymentSnapshot = await transaction.get(paymentRef);
    if (paymentSnapshot.exists) return { result: 'duplicate' };

    const matchSnapshot = await transaction.get(matchRef);
    const participantSnapshot = await transaction.get(participantRef);
    const userSnapshot = await transaction.get(userRef);
    const match = matchSnapshot.exists ? matchSnapshot.data() : null;
    const existing = participantSnapshot.exists ? participantSnapshot.data() : {};
    const user = userSnapshot.exists ? userSnapshot.data() : {};

    const payment = {
      paymentId: session.id,
      userId: uid,
      matchId,
      organiserId: match?.organiserId || '',
      amount,
      platformFee: fee,
      total,
      currency: 'GBP',
      paymentProvider: 'stripe',
      mockPayment: false,
      stripeSessionId: session.id,
      stripePaymentIntentId: session.payment_intent || null,
      createdAt: new Date(),
    };

    const alreadyIn = CONFIRMED_STATUSES.has(existing.attendanceStatus);
    const cannotJoin =
      !match ||
      match.status === 'Cancelled' ||
      match.status === 'Completed' ||
      (match.joinedPlayerCount || 0) >= (match.totalPlayersNeeded || 0);
    if (alreadyIn || cannotJoin) {
      transaction.set(paymentRef, { ...payment, status: 'RefundPending' });
      return { result: 'refund', title: match?.title || '' };
    }

    const joinedAt = new Date();
    const participant = {
      userId: uid,
      fullName: existing.fullName || user.fullName || '',
      position: existing.position || position || 'Any',
      skillLevel: existing.skillLevel || user.skillLevel || 'Casual',
      abilityRatingAtJoin: existing.abilityRatingAtJoin ?? user.abilityRating ?? 0,
      reliabilityScoreAtJoin: existing.reliabilityScoreAtJoin ?? user.reliabilityScore ?? 100,
      paymentStatus: 'Confirmed',
      joinedAt: existing.joinedAt || joinedAt,
      approvedAt: existing.approvedAt || null,
      amountPaid: total,
      amountOwed: 0,
      attendanceStatus: 'Joined',
      organiserApproved: true,
      requiresApproval: false,
      photoUrl: existing.photoUrl || user.photoUrl || null,
    };
    const newCount = (match.joinedPlayerCount || 0) + 1;
    const newStatus =
      newCount >= (match.totalPlayersNeeded || 0) ? 'Full' : 'Open';

    transaction.set(paymentRef, { ...payment, status: 'Succeeded' });
    transaction.set(participantRef, participant, { merge: true });
    transaction.set(
      joinedRef,
      {
        matchId,
        joinedAt: participant.joinedAt,
        paymentStatus: 'Confirmed',
        attendanceStatus: 'Joined',
        position: participant.position,
        matchDateTime: match.startDateTime || null,
        amountOwed: 0,
        requiresApproval: false,
        organiserApproved: true,
      },
      { merge: true },
    );
    transaction.update(matchRef, {
      joinedPlayerCount: newCount,
      status: newStatus,
      updatedAt: new Date(),
    });
    return { result: 'fulfilled', title: match.title || 'the match' };
  });

  if (outcome.result === 'fulfilled') {
    await pushToUser(uid, {
      title: `You're in — ${outcome.title}`,
      body: 'Payment received. Your spot is confirmed.',
      data: { type: 'paymentConfirmed', matchId },
    });
  } else if (outcome.result === 'refund') {
    if (session.payment_intent) {
      await stripe.refunds.create({ payment_intent: session.payment_intent });
      await paymentRef.update({ status: 'Refunded', refundedAt: new Date() });
    }
    await pushToUser(uid, {
      title: 'Payment refunded',
      body: 'The match filled up or was cancelled before your payment completed. You have been refunded in full.',
      data: { type: 'paymentRefunded', matchId },
    });
  }
}

/** Stripe calls this endpoint; the signature check proves it really is Stripe. */
exports.stripeWebhook = onRequest(
  { region: REGION, secrets: [stripeSecretKey, stripeWebhookSecret] },
  async (request, response) => {
    const stripe = new Stripe(stripeSecretKey.value());
    let event;
    try {
      event = stripe.webhooks.constructEvent(
        request.rawBody,
        request.headers['stripe-signature'],
        stripeWebhookSecret.value(),
      );
    } catch (error) {
      response.status(400).send('Webhook signature verification failed');
      return;
    }

    if (event.type === 'checkout.session.completed') {
      await fulfilCheckout(stripe, event.data.object);
    }
    response.status(200).send('ok');
  },
);

// ---------------------------------------------------------------------------
// Reputation: reliability scores and ability ratings (backend-authoritative)
// ---------------------------------------------------------------------------
//
// Clients can no longer write any reputation field — these triggers are the
// only writers. They react to the participant attendance transitions the
// organiser/player legitimately make, and to rating docs (which the rules
// already gate to attended players of completed matches).

const ATTEND_REWARD = 1;
const EARLY_CANCEL_PENALTY = -1;
const MEDIUM_CANCEL_PENALTY = -3;
const LATE_CANCEL_PENALTY = -8;
const NO_SHOW_PENALTY = -15;

function clampScore(score) {
  return Math.max(0, Math.min(100, score));
}

/** Withdrawal penalty by how long before kick-off the player pulled out. */
function withdrawalPenalty(startDate, whenDate) {
  const hours = (startDate.getTime() - whenDate.getTime()) / 3600000;
  if (hours > 24) return EARLY_CANCEL_PENALTY;
  if (hours >= 6) return MEDIUM_CANCEL_PENALTY;
  return LATE_CANCEL_PENALTY;
}

function toDateOrNow(value) {
  return value && typeof value.toDate === 'function' ? value.toDate() : new Date();
}

/**
 * Apply a reliability change to a user, idempotently. The event doc id is
 * deterministic (matchId_eventType), so a re-fired trigger — or the same
 * outcome arriving via two code paths — applies exactly once.
 */
async function applyReputation(uid, { matchId, eventType, scoreChange, note, counters = {} }) {
  const db = getFirestore();
  const userRef = db.collection('users').doc(uid);
  const eventRef = userRef.collection('reliabilityEvents').doc(`${matchId}_${eventType}`);

  await db.runTransaction(async (transaction) => {
    const eventSnap = await transaction.get(eventRef);
    if (eventSnap.exists) return; // already applied

    const userSnap = await transaction.get(userRef);
    const before = Number(userSnap.data()?.reliabilityScore ?? 100);
    const after = clampScore(before + scoreChange);
    const now = new Date();

    const update = {
      reliabilityScore: after,
      lastReliabilityUpdateAt: now,
      updatedAt: now,
    };
    for (const [key, amount] of Object.entries(counters)) {
      update[key] = FieldValue.increment(amount);
    }

    transaction.set(userRef, update, { merge: true });
    transaction.set(eventRef, {
      matchId,
      eventType,
      scoreChange,
      scoreBefore: before,
      scoreAfter: after,
      note: note || '',
      createdAt: now,
    });
  });
}

/** Reliability bookkeeping from participant attendance transitions. */
exports.onParticipantReputation = onDocumentUpdated(
  { document: 'matches/{matchId}/participants/{uid}', region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const from = before.attendanceStatus;
    const to = after.attendanceStatus;
    if (from === to) return;
    const { matchId, uid } = event.params;

    if (from === 'Joined' && (to === 'Cancelled' || to === 'LateCancelled')) {
      // Recompute the penalty from kick-off timing — never trust the label
      // the client wrote, which is exactly what it could lie about.
      const matchSnap = await getFirestore().collection('matches').doc(matchId).get();
      const start = toDateOrNow(matchSnap.data()?.startDateTime);
      const when = toDateOrNow(after.cancelledAt);
      const penalty = withdrawalPenalty(start, when);
      const late = penalty <= MEDIUM_CANCEL_PENALTY;
      await applyReputation(uid, {
        matchId,
        eventType: late ? 'LateCancellation' : 'EarlyCancellation',
        scoreChange: penalty,
        note: after.withdrawalReason || 'Player withdrew before kick-off.',
        counters: late
          ? { cancelledMatches: 1, lateCancellations: 1 }
          : { cancelledMatches: 1 },
      });
    } else if (to === 'Attended') {
      await applyReputation(uid, {
        matchId,
        eventType: 'MatchAttended',
        scoreChange: ATTEND_REWARD,
        note: 'Player attended the match.',
        counters: { attendedMatches: 1, completedMatches: 1, matchesPlayed: 1 },
      });
    } else if (to === 'NoShow') {
      await applyReputation(uid, {
        matchId,
        eventType: 'NoShow',
        scoreChange: NO_SHOW_PENALTY,
        note: 'Player did not show up.',
        counters: { completedMatches: 1, matchesPlayed: 1, noShows: 1 },
      });
    }
  },
);

/** Ability rating aggregate, recomputed when a rating doc is created. */
exports.onRatingCreated = onDocumentCreated(
  { document: 'matches/{matchId}/ratings/{ratingId}', region: REGION },
  async (event) => {
    const rating = event.data?.data();
    if (!rating) return;
    const ratedUserId = rating.ratedUserId;
    const value = Number(rating.abilityRating);
    if (!ratedUserId || !Number.isFinite(value)) return;
    const { matchId, ratingId } = event.params;

    const db = getFirestore();
    const ratingRef = event.data.ref;
    const userRef = db.collection('users').doc(ratedUserId);
    const evidenceRef = userRef
      .collection('abilityRatings')
      .doc(`${matchId}_${rating.ratedByUserId}`);

    await db.runTransaction(async (transaction) => {
      const ratingSnap = await transaction.get(ratingRef);
      if (ratingSnap.data()?.aggregated === true) return; // already counted

      const userSnap = await transaction.get(userRef);
      const data = userSnap.data() || {};
      const average = Number(data.abilityRating ?? data.rating ?? 3.0);
      const count = Number(data.abilityRatingCount ?? 0);
      const newCount = count + 1;
      const newAverage = Math.round(((average * count + value) / newCount) * 100) / 100;
      const now = new Date();

      transaction.set(
        userRef,
        {
          abilityRating: newAverage,
          rating: newAverage,
          abilityRatingCount: newCount,
          lastAbilityRatingAt: now,
          updatedAt: now,
        },
        { merge: true },
      );
      transaction.set(evidenceRef, {
        ratingId,
        matchId,
        ratedByUserId: rating.ratedByUserId,
        rating: value,
        createdAt: now,
      });
      transaction.update(ratingRef, { aggregated: true });
    });
  },
);
