import http from 'node:http';

const KEY = process.env.RENTCAST_API_KEY;
const PORT = Number(process.env.PORT || 3000);
const BASE = 'https://api.rentcast.io/v1';
const cache = new Map();
const TTL = 10 * 60 * 1000;

function reply(res, status, payload) {
  res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': '*' });
  res.end(JSON.stringify(payload));
}
async function rentcast(path, params) {
  const url = new URL(BASE + path);
  Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, String(value)));
  const cacheKey = url.toString();
  const existing = cache.get(cacheKey);
  if (existing && Date.now() - existing.time < TTL) return existing.value;
  const response = await fetch(url, { headers: { 'X-Api-Key': KEY, Accept: 'application/json' }, signal: AbortSignal.timeout(12000) });
  if (!response.ok) throw new Error(`Data provider returned ${response.status}`);
  const value = await response.json();
  if (cache.size > 1000) cache.clear();
  cache.set(cacheKey, { time: Date.now(), value });
  return value;
}
function normalize(p, active) {
  const price = active ? p.price : (p.lastSalePrice ?? null);
  const assessments = p.taxAssessments && Object.values(p.taxAssessments);
  const latestAssessment = assessments?.length ? assessments.at(-1) : null;
  const assessmentValue = latestAssessment?.value ?? latestAssessment?.total ?? null;
  return {
    id: `${active ? 'sale' : 'record'}-${p.id || p.formattedAddress}`,
    address: p.formattedAddress || 'Address unavailable',
    latitude: p.latitude, longitude: p.longitude,
    price: active ? price : (assessmentValue ?? price),
    priceType: active ? 'Asking price' : (assessmentValue != null ? 'Tax-assessed value' : (price != null ? 'Last recorded sale price' : 'Value unavailable')),
    status: active ? 'Active' : 'Off Market',
    bedrooms: p.bedrooms ?? null, bathrooms: p.bathrooms ?? null,
    squareFootage: p.squareFootage ?? null,
    lastSalePrice: p.lastSalePrice ?? null, lastSaleDate: p.lastSaleDate ?? null
  };
}
const server = http.createServer(async (req, res) => {
  try {
    if (req.method !== 'GET') return reply(res, 405, { error: 'Method not allowed' });
    const url = new URL(req.url, `http://localhost:${PORT}`);
    if (url.pathname === '/health') return reply(res, 200, { ok: true, configured: Boolean(KEY) });
    if (!KEY) return reply(res, 503, { error: 'RENTCAST_API_KEY is not configured' });
    if (url.pathname === '/api/properties') {
      const latitude = Number(url.searchParams.get('latitude'));
      const longitude = Number(url.searchParams.get('longitude'));
      const radius = Number(url.searchParams.get('radius'));
      const mode = url.searchParams.get('mode') || 'both';
      if (![latitude, longitude, radius].every(Number.isFinite) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180 || radius < 0.1 || radius > 25 || !['both','listed','offmarket'].includes(mode)) return reply(res, 400, { error: 'Invalid search parameters' });
      const params = { latitude, longitude, radius, limit: 250 };
      const [sale, records] = await Promise.all([
        mode !== 'offmarket' ? rentcast('/listings/sale', { ...params, status: 'Active' }) : [],
        mode !== 'listed' ? rentcast('/properties', params) : []
      ]);
      const active = sale.filter(p => p.latitude != null && p.longitude != null).map(p => normalize(p, true));
      const listingAddresses = new Set(active.map(p => p.address.toLowerCase()));
      const offmarket = records.filter(p => p.latitude != null && p.longitude != null && !listingAddresses.has((p.formattedAddress || '').toLowerCase())).map(p => normalize(p, false));
      return reply(res, 200, { properties: [...active, ...offmarket] });
    }
    if (url.pathname === '/api/estimate') {
      const address = url.searchParams.get('address');
      if (!address || address.length > 250) return reply(res, 400, { error: 'Valid address required' });
      const data = await rentcast('/avm/value', { address });
      return reply(res, 200, { price: data.price ?? null, priceRangeLow: data.priceRangeLow ?? null, priceRangeHigh: data.priceRangeHigh ?? null });
    }
    return reply(res, 404, { error: 'Not found' });
  } catch (error) { console.error(error); return reply(res, 502, { error: 'Property data unavailable' }); }
});
server.listen(PORT, '0.0.0.0', () => console.log(`PropertyMap API listening on ${PORT}`));
