/**
 * NextMatch push notification fan-out.
 *
 * These functions run with admin privileges (they bypass Firestore security
 * rules), so they are also the natural home for the reputation/payment
 * writes listed in SECURITY.md — that migration is still to come.
 */
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const REGION = 'europe-west2'; // London — closest to the user base.

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
