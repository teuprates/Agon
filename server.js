if (process.env.NODE_ENV !== "test") require("dotenv").config();
require("./config/env").validateEnv();

const app = require("./app");
const port = Number(process.env.PORT) || 3500;

if (require.main === module) {
  app.listen(port, () => {
    console.log(`Agon rodando na porta ${port}`);
  });
}

module.exports = app;
