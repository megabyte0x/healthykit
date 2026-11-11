type Entry = { body: string; groups: number; keyBytes: number; expiresAt: number; bytes: number };

export class SummaryCache {
    private entries = new Map<string, Entry>();
    private bytes = 0;
    constructor(private limits = { bytes: 8 * 1024 * 1024, entryBytes: 1024 * 1024, entries: 128, ttlMs: 60_000 }, private clock = Date.now) { }
    get(key: string) {
        const entry = this.entries.get(key);
        if (!entry) return;
        this.remove(key);
        if (entry.expiresAt <= this.clock()) return;
        this.entries.set(key, entry);
        this.bytes += entry.bytes;
        return entry;
    }
    put(key: string, body: string, groups: number, keyBytes: number) {
        this.remove(key);
        if (key.length + body.length > this.limits.entryBytes) return;
        const bytes = new TextEncoder().encode(key).length + new TextEncoder().encode(body).length;
        if (bytes > this.limits.entryBytes || bytes > this.limits.bytes) return;
        for (const [existing, entry] of this.entries)
            if (entry.expiresAt <= this.clock()) this.remove(existing);
        while (this.entries.size && (this.bytes + bytes > this.limits.bytes || this.entries.size >= this.limits.entries))
            this.remove(this.entries.keys().next().value!);
        this.entries.set(key, { body, groups, keyBytes, bytes, expiresAt: this.clock() + this.limits.ttlMs });
        this.bytes += bytes;
    }
    private remove(key: string) {
        const entry = this.entries.get(key);
        if (entry) this.bytes -= entry.bytes;
        this.entries.delete(key);
    }
}
