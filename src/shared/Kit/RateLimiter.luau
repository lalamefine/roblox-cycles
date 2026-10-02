--!strict
-- Limiteur de débit à seau de jetons, une instance par clé (ex. UserId).
-- Module pur : l'horloge est injectable pour les tests.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, last: number }

export type RateLimiter = typeof(setmetatable(
	{} :: {
		capacity: number,
		refillPerSecond: number,
		clock: () -> number,
		buckets: { [any]: Bucket },
	},
	RateLimiter
))

-- capacity : rafale maximale ; refillPerSecond : débit soutenu.
function RateLimiter.new(capacity: number, refillPerSecond: number, clock: (() -> number)?): RateLimiter
	return setmetatable({
		capacity = capacity,
		refillPerSecond = refillPerSecond,
		clock = clock or os.clock,
		buckets = {},
	}, RateLimiter)
end

-- Consomme un jeton ; renvoie false si la clé dépasse son quota.
function RateLimiter.allow(self: RateLimiter, key: any, cost: number?): boolean
	local now = self.clock()
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.capacity, last = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.capacity, bucket.tokens + (now - bucket.last) * self.refillPerSecond)
	bucket.last = now
	local c = cost or 1
	if bucket.tokens < c then
		return false
	end
	bucket.tokens -= c
	return true
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
