import {initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {didTakeLead, repsToRetakeLead} from "./competition";

initializeApp();

const db = getFirestore();
const region = "europe-west1";

type FriendStats = {
  todayCount?: number;
  todayKey?: string;
};

type PublicProfile = {
  username?: string;
  displayName?: string;
};

type CompetitionNotification = {
  type: "lead_change";
  title: string;
  body: string;
  actorUid: string;
  competitorUid: string;
  dayKey: string;
  createdAt: FieldValue;
  readAt: null;
  deliveryStatus: "pending";
};

export const notifyLeadChanges = onDocumentWritten(
  {
    document: "friendStats/{uid}",
    region,
    retry: true,
  },
  async (event) => {
    const actorUid = event.params.uid;
    const before = (event.data?.before.data() ?? {}) as FriendStats;
    const after = (event.data?.after.data() ?? {}) as FriendStats;
    const dayKey = after.todayKey;
    if (!dayKey) return;

    const previousCount = before.todayKey === dayKey ? before.todayCount ?? 0 : 0;
    const currentCount = after.todayCount ?? 0;
    if (currentCount <= previousCount) return;

    const friendLinks = await db
      .collection("users")
      .doc(actorUid)
      .collection("friends")
      .get();
    if (friendLinks.empty) return;

    const friendIds = friendLinks.docs.map((document) => document.id);
    const actorProfileRef = db.collection("publicProfiles").doc(actorUid);
    const friendStatRefs = friendIds.map((uid) =>
      db.collection("friendStats").doc(uid),
    );
    const friendProfileRefs = friendIds.map((uid) =>
      db.collection("publicProfiles").doc(uid),
    );
    const [actorProfile, ...documents] = await db.getAll(
      actorProfileRef,
      ...friendStatRefs,
      ...friendProfileRefs,
    );
    const stats = documents.slice(0, friendIds.length);
    const profiles = documents.slice(friendIds.length);
    const actorName = profileName(actorProfile.data() as PublicProfile | undefined);
    const batch = db.batch();
    let leadChanges = 0;

    friendIds.forEach((friendUid, index) => {
      const friendStats = (stats[index].data() ?? {}) as FriendStats;
      const friendCount = friendStats.todayKey === dayKey
        ? friendStats.todayCount ?? 0
        : 0;
      const crossedLead = didTakeLead(previousCount, currentCount, friendCount);
      if (!crossedLead) return;

      leadChanges += 1;
      const friendName = profileName(
        profiles[index].data() as PublicProfile | undefined,
      );
      const lead = currentCount - friendCount;
      const actorNotification = notification(
        `You passed @${friendName}`,
        `You are ${lead} ${lead === 1 ? "rep" : "reps"} ahead today.`,
        actorUid,
        friendUid,
        dayKey,
      );
      const friendNotification = notification(
        `@${actorName} passed you`,
        `Log ${repsToRetakeLead(currentCount, friendCount)} reps to take the lead back.`,
        actorUid,
        actorUid,
        dayKey,
      );

      batch.set(
        db
          .collection("users")
          .doc(actorUid)
          .collection("notifications")
          .doc(`${event.id}_${friendUid}_ahead`),
        actorNotification,
      );
      batch.set(
        db
          .collection("users")
          .doc(friendUid)
          .collection("notifications")
          .doc(`${event.id}_${actorUid}_passed`),
        friendNotification,
      );
    });

    if (leadChanges > 0) await batch.commit();
  },
);

export const deliverCompetitionNotification = onDocumentCreated(
  {
    document: "users/{uid}/notifications/{notificationId}",
    region,
    retry: false,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const payload = snapshot.data() as CompetitionNotification;
    if (payload.type !== "lead_change") return;

    const tokenSnapshot = await db
      .collection("users")
      .doc(event.params.uid)
      .collection("pushTokens")
      .get();
    const tokens = tokenSnapshot.docs
      .map((document) => document.get("token") as string | undefined)
      .filter((token): token is string => Boolean(token));

    if (tokens.length === 0) {
      await snapshot.ref.update({deliveryStatus: "no_tokens"});
      return;
    }

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        type: payload.type,
        notificationId: event.params.notificationId,
        actorUid: payload.actorUid,
        competitorUid: payload.competitorUid,
        dayKey: payload.dayKey,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "pushlog_competition",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            threadId: "pushlog_competition",
          },
        },
      },
    });

    const invalidTokens: string[] = [];
    response.responses.forEach((result, index) => {
      const code = result.error?.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(tokens[index]);
      }
    });
    if (invalidTokens.length > 0) {
      const cleanup = db.batch();
      invalidTokens.forEach((token) => {
        cleanup.delete(
          db
            .collection("users")
            .doc(event.params.uid)
            .collection("pushTokens")
            .doc(token),
        );
      });
      await cleanup.commit();
    }

    await snapshot.ref.update({
      deliveryStatus: response.failureCount === 0 ? "sent" : "partial",
      deliveredAt: FieldValue.serverTimestamp(),
      deliveredDevices: response.successCount,
      failedDevices: response.failureCount,
    });
  },
);

function notification(
  title: string,
  body: string,
  actorUid: string,
  competitorUid: string,
  dayKey: string,
): CompetitionNotification {
  return {
    type: "lead_change",
    title,
    body,
    actorUid,
    competitorUid,
    dayKey,
    createdAt: FieldValue.serverTimestamp(),
    readAt: null,
    deliveryStatus: "pending",
  };
}

function profileName(profile?: PublicProfile): string {
  return (
    profile?.username?.trim() ||
    profile?.displayName?.trim() ||
    "friend"
  ).replace(/^@/, "");
}
