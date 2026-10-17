const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

/**
 * Validates and ensures server-side dependency integrity on workflow changes.
 * Idempotent trigger.
 */
exports.onWorkflowWritten = onDocumentWritten('workflows/{workflowId}', async (event) => {
  const snapshot = event.data.after;
  if (!snapshot.exists) {
    // Workflow was deleted
    return null;
  }

  const workflow = snapshot.data();
  const steps = workflow.steps || [];

  // Check if all steps are completed
  const allCompleted = steps.length > 0 && steps.every((s) => s.status === 'completed');
  const targetStatus = allCompleted ? 'completed' : 'active';

  if (workflow.status !== 'archived' && workflow.status !== targetStatus) {
    await snapshot.ref.update({
      status: targetStatus,
      completedAt: allCompleted ? admin.firestore.FieldValue.serverTimestamp() : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return null;
});

/**
 * Daily scheduled reminder for overdue and upcoming workflow deadlines.
 */
exports.checkWorkflowDeadlines = onSchedule('every 24 hours', async (event) => {
  const now = new Date();
  const threeDaysAhead = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

  const snapshot = await db.collection('workflows')
    .where('status', '==', 'active')
    .get();

  for (const doc of snapshot.docs) {
    const workflow = doc.data();
    if (!workflow.dueDate) continue;

    const dueDate = new Date(workflow.dueDate);
    if (dueDate < now) {
      // Overdue workflow alert
      await db.collection('activities').add({
        id: `alert-${doc.id}-${now.getTime()}`,
        userId: workflow.userId,
        workflowId: doc.id,
        workflowTitle: workflow.title,
        type: 'stepBlocked',
        description: `Reminder: Workflow "${workflow.title}" is overdue since ${dueDate.toDateString()}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (dueDate <= threeDaysAhead) {
      // Upcoming deadline reminder
      await db.collection('activities').add({
        id: `reminder-${doc.id}-${now.getTime()}`,
        userId: workflow.userId,
        workflowId: doc.id,
        workflowTitle: workflow.title,
        type: 'workflowEdited',
        description: `Upcoming deadline: Workflow "${workflow.title}" is due on ${dueDate.toDateString()}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  return null;
});
