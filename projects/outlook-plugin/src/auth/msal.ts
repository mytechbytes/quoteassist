// MSAL auth config (CC-05/06). The token acquisition (silent refresh + popup
// fallback, in-memory only — never persisted/logged) is wired up when
// @azure/msal-browser is added during Phase 2 completion. This module pins the
// config shape + the token-provider interface the ApiClient depends on.

export interface MsalConfig {
  clientId: string;
  tenantId: string;
  authority: string;
  scopes: string[];
}

export function buildConfig(env: { clientId: string; tenantId: string }): MsalConfig {
  return {
    clientId: env.clientId,
    tenantId: env.tenantId,
    authority: `https://login.microsoftonline.com/${env.tenantId}`,
    scopes: ["openid", "profile", "offline_access", "User.Read", "Mail.ReadWrite"],
  };
}

export type TokenProvider = () => Promise<string>;

// Placeholder provider until @azure/msal-browser is wired in. Keeps the type
// contract honest so the ApiClient compiles and is testable.
export function tokenProvider(_config: MsalConfig): TokenProvider {
  return async () => {
    throw new Error("MSAL token acquisition is wired in Phase 2 completion");
  };
}
