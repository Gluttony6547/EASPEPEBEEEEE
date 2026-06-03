// ============================================================
// KONTRAK TIM — Jangan ubah tanpa diskusi 
// ============================================================

class FSCollection {
  static const users          = 'users';
  static const assessments    = 'assessments';
  static const logs           = 'logs';
  static const challenges     = 'challenges';
  static const userChallenges = 'userChallenges';
}

class FSField {
  // == users ==
  static const uid         = 'uid';
  static const email       = 'email';
  static const displayName = 'displayName';
  static const fcmToken    = 'fcmToken';
  static const createdAt   = 'createdAt';

  // == assessments ==
  static const userId    = 'userId';
  static const answers   = 'answers';
  static const score     = 'score';
  static const riskLevel = 'riskLevel';

  // == logs ==
  static const productName = 'productName';
  static const portionGram = 'portionGram';
  static const sugarGram   = 'sugarGram';
  static const source      = 'source';
  static const loggedAt    = 'loggedAt';

  // == challenges ==
  static const title           = 'title';
  static const description     = 'description';
  static const targetSugarGram = 'targetSugarGram';
  static const durationDays    = 'durationDays';
  static const badgeIcon       = 'badgeIcon';

  // == userChallenges ==
  static const status       = 'status';
  static const progressDays = 'progressDays';
  static const joinedAt     = 'joinedAt';
  static const completedAt  = 'completedAt';
}

class FSStatus {
  static const active    = 'active';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

class FSRiskLevel {
  static const low    = 'low';
  static const medium = 'medium';
  static const high   = 'high';
}