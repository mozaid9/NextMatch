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
const { getFirestore } = require('firebase-admin/firestore');
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

/** Organiser cancels a match → tell everyone still holding a spot. */
exports.onMatchCancelled = onDocumentUpdated(
  { document: 'matches/{matchId}', region: REGION },
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
      if (typeof url !== 'string' || !/^https?:\/\//.test(url)) {
        throw new HttpsError('invalid-argument', 'Return URLs must be http(s).');
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
