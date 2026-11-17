/* GitHub/Supabase direct. Aucune donnée métier fictive et aucun backend caché. */
const config = globalThis.CHR_CONFIG || {};
const BASE = String(config.url || '').replace(/\/$/, '');
const KEY = String(config.publishableKey || '');
const SESSION = 'chr-supabase-session-v1';
export function configured() { return /^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(BASE) && KEY.length > 20; }
export class ApiError extends Error {
  constructor(message, status = 0, details = null) { super(message); this.name = 'ApiError'; this.status = status; this.details = details; }
}
let auth = null;
try { auth = JSON.parse(sessionStorage.getItem(SESSION) || 'null'); } catch { auth = null; }
export function getSession() { return auth; }
function saveSession(value) { auth = value; if (value) sessionStorage.setItem(SESSION, JSON.stringify(value)); else sessionStorage.removeItem(SESSION); }
function resolveUrl(path, params) {
  const url = new URL(BASE + path);
  for (const [key,value] of Object.entries(params || {})) {
    if (value !== undefined && value !== null) url.searchParams.set(key, String(value));
  }
  return url.toString();
}
async function request(path, options = {}, authorized = true, retry = true) {
  if (!configured()) throw new ApiError('Configuration Supabase manquante.');
  const headers = { apikey: KEY, Accept: 'application/json', ...options.headers };
  if (authorized && auth?.access_token) headers.Authorization = 'Bearer ' + auth.access_token;
  if (options.body !== undefined && !headers['Content-Type']) headers['Content-Type'] = 'application/json';
  let response;
  try { response = await fetch(resolveUrl(path,options.params), {method: options.method || 'GET',headers,body: options.body !== undefined ? JSON.stringify(options.body) : undefined,signal: options.signal}); }
  catch { throw new ApiError('Connexion indisponible. Vérifie ton réseau.'); }
  if (response.status === 401 && authorized && retry && auth?.refresh_token) {
    try { await refresh(); return request(path,options,authorized,false); }
    catch { saveSession(null); throw new ApiError('Session expirée. Reconnecte-toi.',401); }
  }
  const raw = await response.text();
  let data = null;
  try { data = raw ? JSON.parse(raw) : null; } catch { data = raw; }
  if (!response.ok) throw new ApiError(typeof data === 'object' && data ? (data.message || data.msg || data.error_description || data.error || 'Erreur serveur') : 'Erreur serveur',response.status,data);
  return data;
}
export async function login(email,password) {
  const data = await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email,password}},false);
  if (!data?.access_token) throw new ApiError('Authentification sans jeton.');
  saveSession(data);
  return data;
}
export async function register(email,password) {
  return request('/auth/v1/signup',{method:'POST',body:{email,password}},false);
}
export async function resetPassword(email) {
  return request('/auth/v1/recover',{method:'POST',body:{email}},false);
}
export async function refresh() {
  if (!auth?.refresh_token) throw new ApiError('Session absente.',401);
  const data = await request('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:{refresh_token:auth.refresh_token}},false,false);
  if (!data?.access_token) throw new ApiError('Session expirée.',401);
  saveSession(data);
  return data;
}
export async function currentUser() {
  if (!auth?.access_token) return null;
  try { return await request('/auth/v1/user'); }
  catch(e) { if (e.status === 401) saveSession(null); throw e; }
}
export async function logout() {
  try { if (auth?.access_token) await request('/auth/v1/logout',{method:'POST'}); }
  finally { saveSession(null); }
}
function filterParams(storeId, opts={}) {
  return {'store_id':'eq.'+storeId, select:opts.select || '*', order:opts.order || 'created_at.desc', limit: opts.limit || 500,...opts.filters};
}
export async function list(table,storeId,opts={}) {
  const data = await request('/rest/v1/'+encodeURIComponent(table),{params:filterParams(storeId,opts)});
  return Array.isArray(data)? data : [];
}
export async function insert(table,record) {
  const data = await request('/rest/v1/'+encodeURIComponent(table),{method:'POST',headers:{Prefer:'return=representation'},body:record});
  return data?.[0] || null;
}
export async function update(table,id,storeId,record) {
  const data = await request('/rest/v1/'+encodeURIComponent(table),{method:'PATCH',headers:{Prefer:'return=representation'},params:{id:'eq.'+id,store_id:'eq.'+storeId},body:record});
  if (!data?.length) throw new ApiError('Modification refusée ou élément introuvable.',403);
  return data[0];
}
export async function remove(table,id,storeId) {
  const data = await request('/rest/v1/'+encodeURIComponent(table),{method:'DELETE',headers:{Prefer:'return=representation'},params:{id:'eq.'+id,store_id:'eq.'+storeId}});
  if (!data?.length) throw new ApiError('Suppression refusée ou élément introuvable.',403);
}
export async function rpc(name,payload) {
  return request('/rest/v1/rpc/'+encodeURIComponent(name),{method:'POST',body:payload});
}
export async function getStores(userId) {
  // Accès autorisé par RLS aux entreprises dont l'utilisateur est propriétaire ou membre.
  return request('/rest/v1/stores',{params:{select:'*',order:'created_at.asc'}});
}
export async function createStore(userId,name,slug) {
  return insert('stores',{owner_user_id:userId,name,slug,currency:'EUR',timezone:'Europe/Paris'});
}
export async function getRelated(table,storeId) {
  return list(table,storeId,{limit:1000,order:'created_at.asc'});
}
