--!strict
-- Signal minimal (connect / fire / once) sans dépendance Roblox.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }

export type Signal<T...> = typeof(setmetatable({} :: { handlers: { [Connection]: (T...) -> () } }, Signal))

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ handlers = {} }, Signal) :: any
end

function Signal.Connect<T...>(self: Signal<T...>, fn: (T...) -> ()): Connection
	local handlers = self.handlers
	local conn = { Connected = true } :: any
	function conn.Disconnect(c: Connection)
		c.Connected = false
		handlers[c] = nil
	end
	handlers[conn] = fn
	return conn
end

function Signal.Once<T...>(self: Signal<T...>, fn: (T...) -> ()): Connection
	local conn: Connection
	conn = self:Connect(function(...: T...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	-- Copie pour tolérer les déconnexions pendant l'itération.
	for conn, fn in table.clone(self.handlers) do
		if conn.Connected then
			fn(...)
		end
	end
end

function Signal.DisconnectAll<T...>(self: Signal<T...>)
	for conn in self.handlers do
		conn.Connected = false
	end
	table.clear(self.handlers)
end

return Signal
