const express = require('express');
const supabase = require('../config/db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Apply auth middleware to all routes
router.use(authMiddleware);

// GET /profile
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;

    const { data: profile, error } = await supabase
      .from('user_profiles')
      .select('gender, height, weight, body_type, goal, coach_style')
      .eq('user_id', userId)
      .single();

    if (error || !profile) {
      return res.status(404).json({ error: '프로필을 찾을 수 없습니다' });
    }

    return res.status(200).json({ profile });
  } catch (err) {
    console.error('Get profile error:', err);
    return res.status(500).json({ error: '서버 오류가 발생했습니다' });
  }
});

// PUT /profile
router.put('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { gender, height, weight, bodyType, goal, coachStyle } = req.body;

    // Convert camelCase to snake_case
    const profileData = {
      user_id: userId,
      gender,
      height,
      weight,
      body_type: bodyType,
      goal,
      coach_style: coachStyle || 'warm',
      updated_at: new Date().toISOString()
    };

    // UPSERT: Insert or update
    const { data: profile, error } = await supabase
      .from('user_profiles')
      .upsert(profileData, { onConflict: 'user_id' })
      .select('gender, height, weight, body_type, goal, coach_style')
      .single();

    if (error) {
      console.error('Upsert profile error:', error);
      return res.status(500).json({ error: '프로필 저장에 실패했습니다' });
    }

    return res.status(200).json({ profile });
  } catch (err) {
    console.error('Put profile error:', err);
    return res.status(500).json({ error: '서버 오류가 발생했습니다' });
  }
});

module.exports = router;
