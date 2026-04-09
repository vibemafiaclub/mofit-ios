require('dotenv').config();

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// Cleanup: delete users with @test.com emails
const cleanup = async () => {
  const { error } = await supabase
    .from('users')
    .delete()
    .like('email', '%@test.com');

  if (error) {
    console.error('Cleanup error:', error);
  }
};

module.exports = { supabase, cleanup };
