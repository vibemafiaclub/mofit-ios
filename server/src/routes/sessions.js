const express = require('express');
const supabase = require('../config/db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Apply auth middleware to all routes
router.use(authMiddleware);

// Helper: Convert snake_case DB row to camelCase response
const toCamelCase = (session) => ({
  id: session.id,
  exerciseType: session.exercise_type,
  startedAt: session.started_at,
  endedAt: session.ended_at,
  totalDuration: session.total_duration,
  repCounts: session.rep_counts,
  createdAt: session.created_at
});

// GET /sessions
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { date } = req.query;

    let query = supabase
      .from('workout_sessions')
      .select('id, exercise_type, started_at, ended_at, total_duration, rep_counts, created_at')
      .eq('user_id', userId)
      .order('started_at', { ascending: false });

    if (date) {
      // Filter by specific date (YYYY-MM-DD)
      const startOfDay = `${date}T00:00:00.000Z`;
      const endOfDay = `${date}T23:59:59.999Z`;
      query = query.gte('started_at', startOfDay).lte('started_at', endOfDay);
    } else {
      // Last 30 days
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      query = query.gte('started_at', thirtyDaysAgo.toISOString());
    }

    const { data: sessions, error } = await query;

    if (error) {
      console.error('Get sessions error:', error);
      return res.status(500).json({ error: '세션 조회에 실패했습니다' });
    }

    return res.status(200).json({
      sessions: sessions.map(toCamelCase)
    });
  } catch (err) {
    console.error('Get sessions error:', err);
    return res.status(500).json({ error: '서버 오류가 발생했습니다' });
  }
});

// POST /sessions
router.post('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { exerciseType, startedAt, endedAt, totalDuration, repCounts } = req.body;

    // Convert camelCase to snake_case
    const sessionData = {
      user_id: userId,
      exercise_type: exerciseType,
      started_at: startedAt,
      ended_at: endedAt,
      total_duration: totalDuration,
      rep_counts: repCounts
    };

    const { data: session, error } = await supabase
      .from('workout_sessions')
      .insert(sessionData)
      .select('id, exercise_type, started_at, ended_at, total_duration, rep_counts, created_at')
      .single();

    if (error) {
      console.error('Insert session error:', error);
      return res.status(500).json({ error: '세션 저장에 실패했습니다' });
    }

    return res.status(201).json({
      session: toCamelCase(session)
    });
  } catch (err) {
    console.error('Post session error:', err);
    return res.status(500).json({ error: '서버 오류가 발생했습니다' });
  }
});

// DELETE /sessions/:id
router.delete('/:id', async (req, res) => {
  try {
    const userId = req.user.id;
    const sessionId = req.params.id;

    // Delete only if both id and user_id match
    const { data, error } = await supabase
      .from('workout_sessions')
      .delete()
      .eq('id', sessionId)
      .eq('user_id', userId)
      .select();

    if (error) {
      console.error('Delete session error:', error);
      return res.status(500).json({ error: '세션 삭제에 실패했습니다' });
    }

    // If no rows were deleted, return 404
    if (!data || data.length === 0) {
      return res.status(404).json({ error: '세션을 찾을 수 없습니다' });
    }

    return res.status(204).send();
  } catch (err) {
    console.error('Delete session error:', err);
    return res.status(500).json({ error: '서버 오류가 발생했습니다' });
  }
});

module.exports = router;
