import { HttpError, type Row } from './store';
export class LocalDates {
    private readonly formatters = new Map<string, Intl.DateTimeFormat>();
    get(value: string, timezone: string): string {
        const date = new Date(value);
        if (Number.isNaN(date.getTime()))
            return value.slice(0, 10);
        const zone = timezone || 'UTC';
        let formatter = this.formatters.get(zone);
        if (!formatter) {
            try {
                formatter = new Intl.DateTimeFormat('en', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' });
            }
            catch {
                return this.get(value, 'UTC');
            }
            if (this.formatters.size < 128)
                this.formatters.set(zone, formatter);
        }
        const parts = Object.fromEntries(formatter.formatToParts(date).map(p => [p.type, p.value]));
        return `${parts.year}-${parts.month}-${parts.day}`;
    }
}
type Stats = {
    count: number;
    sum: number;
    min: number;
    max: number;
};
const empty = (): Stats => ({ count: 0, sum: 0, min: Infinity, max: -Infinity });
function add(stats: Stats, value: number) { stats.count++; stats.sum += value; stats.min = Math.min(stats.min, value); stats.max = Math.max(stats.max, value); }
function merge(a: Stats, b: Stats) { a.count += b.count; a.sum += b.sum; a.min = Math.min(a.min, b.min); a.max = Math.max(a.max, b.max); }
export class Summaries {
    private metrics = new Map<string, {
        key: string[];
        raw: Stats;
        preferred: Stats;
    }>();
    private workouts = new Map<string, {
        key: string[];
        count: number;
        duration: number;
        distance: Stats;
        total: Stats;
        active: Stats;
    }>();
    private keyBytes = 0;
    constructor(private dates: LocalDates, private maxGroups = 50000, private maxKeyBytes = 8 * 1024 * 1024) { }
    private check(key: string) { this.keyBytes += new TextEncoder().encode(key).length; if (this.metrics.size + this.workouts.size > this.maxGroups || this.keyBytes > this.maxKeyBytes)
        throw new HttpError(503, 'Summary capacity exceeded; narrow the requested range'); }
    metric(row: Row) {
        const key = [this.dates.get(row.start_at, row.timezone), row.type, row.unit, row.device_id];
        const id = JSON.stringify(key);
        let group = this.metrics.get(id);
        if (!group) {
            group = { key, raw: empty(), preferred: empty() };
            this.metrics.set(id, group);
            this.check(id);
        }
        add(row.preferred ? group.preferred : group.raw, Number(row.value));
    }
    workout(row: Row) {
        const key = [this.dates.get(row.start_at, row.timezone), row.activity_type], id = JSON.stringify(key);
        let group = this.workouts.get(id);
        if (!group) {
            group = { key, count: 0, duration: 0, distance: empty(), total: empty(), active: empty() };
            this.workouts.set(id, group);
            this.check(id);
        }
        group.count++;
        group.duration += Number(row.duration_seconds);
        for (const [field, target] of [['distance_meters', 'distance'], ['total_energy_kcal', 'total'], ['active_energy_kcal', 'active']] as const)
            if (row[field] !== null)
                add(group[target], Number(row[field]));
    }
    finish() {
        const combined = new Map<string, {
            key: string[];
            stats: Stats;
        }>();
        for (const group of this.metrics.values()) {
            const key = group.key.slice(0, 3), id = JSON.stringify(key);
            let target = combined.get(id);
            if (!target) {
                target = { key, stats: empty() };
                combined.set(id, target);
            }
            merge(target.stats, group.preferred.count ? group.preferred : group.raw);
        }
        const sorted = <T extends {
            key: string[];
        }>(values: Iterable<T>) => [...values].sort((a, b) => a.key.join('\u0000').localeCompare(b.key.join('\u0000')));
        return {
            metric_daily_summaries: sorted(combined.values()).map(({ key: [local_date, type, unit], stats: s }) => ({ local_date, type, unit, sample_count: s.count, total_value: s.sum, average_value: s.sum / s.count, minimum_value: s.min, maximum_value: s.max })),
            workout_daily_summaries: sorted(this.workouts.values()).map(g => ({ local_date: g.key[0], activity_type: g.key[1], workout_count: g.count, duration_minutes: g.duration / 60, distance_km: g.distance.count ? g.distance.sum / 1000 : null, total_energy_kcal: g.total.count ? g.total.sum : null, active_energy_kcal: g.active.count ? g.active.sum : null })),
        };
    }
    get groupKeyBytes() { return this.keyBytes; }
    get groupCount() { return this.metrics.size + this.workouts.size; }
}
