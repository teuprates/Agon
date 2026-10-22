const testLive = async () => {
  // 1. Status check
  const statusRes = await fetch('http://localhost:3500/api/zuka/status');
  console.log('API Status:', await statusRes.json());

  // 2. Chat message
  const authRes = await fetch('http://localhost:3500/api/check-auth');
  const cookie = authRes.headers.get('set-cookie').split(';')[0];
  const headers = { 'Content-Type': 'application/json', 'Cookie': cookie };

  console.log('Sending message to Zuka IA...');
  const chatRes = await fetch('http://localhost:3500/api/zuka/chat', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      message: 'Olá Zuka! Pode me explicar resumidamente o princípio da impessoalidade e dar um exemplo prático de pegadinha da banca Cebraspe?'
    })
  });

  const chatData = await chatRes.json();
  console.log('Zuka IA Status Code:', chatRes.status);
  console.log('Model Used:', chatData.model);
  console.log('Zuka IA Response:\n', chatData.reply);
};

testLive();
