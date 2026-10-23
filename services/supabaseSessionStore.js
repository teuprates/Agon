const session = require("express-session");
const { getSupabaseAdmin } = require("./supabaseClient");

/** Persistent express-session store for stateless Vercel function instances. */
class SupabaseSessionStore extends session.Store {
  constructor({ cleanupIntervalMs = 60 * 60 * 1000 } = {}) {
    super();
    this.cleanupTimer = setInterval(() => this.cleanupExpired().catch((err) => {
      console.error("[SESSION STORE] Falha na limpeza de sessões expiradas:", err.message);
    }), cleanupIntervalMs);
    this.cleanupTimer.unref?.();
  }

  client() {
    const client = getSupabaseAdmin();
    if (!client) throw new Error("Supabase não configurado para armazenar sessões.");
    return client;
  }

  async get(sid, callback) {
    try {
      const { data, error } = await this.client()
        .from("agon_sessions")
        .select("session_data, expires_at")
        .eq("session_id", sid)
        .maybeSingle();
      if (error) throw error;
      if (!data) return callback(null, null);
      if (new Date(data.expires_at).getTime() <= Date.now()) {
        await this.destroy(sid);
        return callback(null, null);
      }
      callback(null, data.session_data);
    } catch (err) {
      callback(err);
    }
  }

  async set(sid, sessionData, callback = () => {}) {
    try {
      const expiresAt = sessionData.cookie?.expires
        ? new Date(sessionData.cookie.expires).toISOString()
        : new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
      const { error } = await this.client().from("agon_sessions").upsert({
        session_id: sid,
        session_data: sessionData,
        expires_at: expiresAt,
      }, { onConflict: "session_id" });
      if (error) throw error;
      callback(null);
    } catch (err) {
      callback(err);
    }
  }

  async destroy(sid, callback = () => {}) {
    try {
      const { error } = await this.client().from("agon_sessions").delete().eq("session_id", sid);
      if (error) throw error;
      callback(null);
    } catch (err) {
      callback(err);
    }
  }

  async touch(sid, sessionData, callback = () => {}) {
    return this.set(sid, sessionData, callback);
  }

  async cleanupExpired() {
    const { error } = await this.client().from("agon_sessions").delete().lt("expires_at", new Date().toISOString());
    if (error) throw error;
  }
}

module.exports = SupabaseSessionStore;
