const { json, method } = require('./_lib/http');

module.exports = function handler(req, res) {
  if (!method(req, res, ['GET'])) return;
  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) return json(res, 503, { error: 'supabase_not_configured' });
  return json(res, 200, { supabaseUrl: url, supabaseAnonKey: anonKey });
};
