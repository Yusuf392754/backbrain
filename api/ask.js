const { json, method, env, body } = require('./_lib/http');
const { requireUser } = require('./_lib/auth');

module.exports = async function handler(req, res) {
  if (!method(req, res, ['POST'])) return;
  const user = await requireUser(req, res, json);
  if (!user) return;
  let input = body(req);
  if (!input || typeof input.question !== 'string' || !input.question.trim()) {
    return json(res, 400, { error: 'question_required' });
  }
  const question = input.question.trim().slice(0, 2000);
  const context = typeof input.context === 'string' ? input.context.slice(0, 12000) : '';
  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${env('OPENAI_API_KEY')}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        temperature: 0.2,
        max_tokens: 400,
        messages: [
          { role: 'system', content: 'You are BackBrain, a concise personal memory assistant. Answer only from the supplied user context. If the context does not contain the answer, say that you do not know and ask the user to add a memory. Never invent medical, financial, credential, or calendar facts.' },
          { role: 'user', content: `User context:\n${context || '(no context supplied)'}\n\nQuestion:\n${question}` }
        ]
      })
    });
    const data = await response.json();
    if (!response.ok) return json(res, response.status === 429 ? 429 : 502, { error: 'ai_provider_error', detail: data.error?.message || 'OpenAI request failed' });
    const answer = data.choices?.[0]?.message?.content?.trim();
    if (!answer) return json(res, 502, { error: 'empty_ai_response' });
    return json(res, 200, { answer, model: data.model || process.env.OPENAI_MODEL || 'gpt-4o-mini' });
  } catch (error) {
    return json(res, 500, { error: 'ai_request_failed', detail: error.message });
  }
};
