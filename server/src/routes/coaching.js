const express = require('express');
const supabase = require('../config/db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Apply auth middleware to all routes
router.use(authMiddleware);

// Helper: Convert snake_case DB row to camelCase response
const toCamelCase = (feedback) => ({
  id: feedback.id,
  date: feedback.date,
  type: feedback.type,
  content: feedback.content,
  createdAt: feedback.created_at
});

// Helper: Get today's date in YYYY-MM-DD format (local time)
const getTodayDate = () => {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

// GET /coaching
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { date } = req.query;

    let query = supabase
      .from('coaching_feedbacks')
      .select('id, date, type, content, created_at')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (date) {
      // Filter by specific date (YYYY-MM-DD)
      query = query.eq('date', date);
    } else {
      // Last 30 days
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      const thirtyDaysAgoStr = thirtyDaysAgo.toISOString().split('T')[0];
      query = query.gte('date', thirtyDaysAgoStr);
    }

    const { data: feedbacks, error } = await query;

    if (error) {
      console.error('Get coaching error:', error);
      return res.status(500).json({ error: '피드백 조회에 실패했습니다' });
    }

    return res.status(200).json({
      feedbacks: feedbacks.map(toCamelCase)
    });
  } catch (err) {
    console.error('Get coaching error:', err);
    return res.status(500).json({ error: '서버 오류가 발생했습니다' });
  }
});

// POST /coaching/request
router.post('/request', async (req, res) => {
  try {
    const userId = req.user.id;
    const { prompt, type } = req.body;

    if (!prompt || !type) {
      return res.status(400).json({ error: 'prompt와 type은 필수입니다' });
    }

    const today = getTodayDate();

    // Check daily usage limit (max 2 feedbacks per day)
    const { count, error: countError } = await supabase
      .from('coaching_feedbacks')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('date', today);

    if (countError) {
      console.error('Count feedbacks error:', countError);
      return res.status(500).json({ error: '사용량 확인에 실패했습니다' });
    }

    if (count >= 2) {
      return res.status(429).json({ error: '오늘 피드백 사용 횟수를 초과했습니다' });
    }

    // Call Claude API
    const claudeApiKey = process.env.CLAUDE_API_KEY;
    if (!claudeApiKey) {
      console.error('CLAUDE_API_KEY not configured');
      return res.status(500).json({ error: 'Claude API가 설정되지 않았습니다' });
    }

    const claudeResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': claudeApiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 1024,
        messages: [
          { role: 'user', content: prompt }
        ]
      })
    });

    if (!claudeResponse.ok) {
      const errorBody = await claudeResponse.text();
      console.error('Claude API error:', claudeResponse.status, errorBody);
      return res.status(500).json({ error: 'Claude API 호출에 실패했습니다' });
    }

    const claudeData = await claudeResponse.json();
    const content = claudeData.content?.[0]?.text || '';

    // Save feedback to database
    const { data: feedback, error: insertError } = await supabase
      .from('coaching_feedbacks')
      .insert({
        user_id: userId,
        date: today,
        type,
        content
      })
      .select('id, date, type, content, created_at')
      .single();

    if (insertError) {
      console.error('Insert feedback error:', insertError);
      return res.status(500).json({ error: '피드백 저장에 실패했습니다' });
    }

    return res.status(201).json({
      feedback: toCamelCase(feedback)
    });
  } catch (err) {
    console.error('Coaching request error:', err);
    return res.status(500).json({ error: '서버 오류가 발생했습니다' });
  }
});

module.exports = router;
