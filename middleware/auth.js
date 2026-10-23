function requireAuth(req, res, next) {
  if (req.session?.user) {
    res.set("Cache-Control", "private, no-store");
    return next();
  }
  return res.redirect("/login");
}

function requireAuthApi(req, res, next) {
  if (req.session?.user) return next();
  return res.status(401).json({ erro: "Autenticação necessária.", codigo: "UNAUTHENTICATED" });
}

function requireRole(...allowedRoles) {
  const normalized = new Set(allowedRoles.map((role) => role === "admin" ? "administrador" : role));
  return (req, res, next) => {
    const role = req.session?.user?.tipo_usuario;
    if (!role) return res.status(401).json({ erro: "Autenticação necessária.", codigo: "UNAUTHENTICATED" });
    if (!normalized.has(role)) return res.status(403).json({ erro: "Você não tem permissão para acessar este recurso." });
    return next();
  };
}

module.exports = { requireAuth, requireAuthApi, requireRole };
