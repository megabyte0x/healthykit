import { HttpError, byteLength, type Row } from './store';
import type { SourceCollation } from './collation';
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
type RecordOrder = {start_at: string; device_id: string; id: string};
const recordOrder = (row: Row): RecordOrder => ({start_at:row.start_at,device_id:row.device_id,id:row.id});
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
        first: RecordOrder;
        raw: Stats;
        preferred: Stats;
    }>();
    private workouts = new Map<string, {
        key: string[];
        first: RecordOrder;
        count: number;
        duration: number;
        distance: Stats;
        total: Stats;
        active: Stats;
    }>();
    private keyBytes = 0;
    constructor(private dates: LocalDates, private maxGroups: number, private maxKeyBytes: number, private collation: SourceCollation) { }
    private check(bytes: number) { this.keyBytes += bytes; if (this.metrics.size + this.workouts.size > this.maxGroups || this.keyBytes > this.maxKeyBytes)
        throw new HttpError(503, 'Summary capacity exceeded; narrow the requested range'); }
    private compareRecords(left: RecordOrder, right: RecordOrder): number {
        if (left.start_at !== right.start_at) return left.start_at > right.start_at ? -1 : 1;
        return this.collation.key(left, right);
    }
    private retainFirst(group: {first: RecordOrder}, row: Row) {
        if (this.compareRecords(row as RecordOrder, group.first) < 0) {
            const next = recordOrder(row);
            this.check(byteLength(next) - byteLength(group.first));
            group.first = next;
        }
    }
    metric(row: Row) {
        const key = [this.dates.get(row.start_at, row.timezone), row.type, row.unit, row.device_id];
        const id = JSON.stringify(key);
        let group = this.metrics.get(id);
        if (!group) {
            group = { key, first: recordOrder(row), raw: empty(), preferred: empty() };
            this.metrics.set(id, group);
            this.check(byteLength(key) + byteLength(group.first));
        }
        this.retainFirst(group, row);
        add(row.preferred ? group.preferred : group.raw, Number(row.value));
    }
    workout(row: Row) {
        const key = [this.dates.get(row.start_at, row.timezone), row.activity_type], id = JSON.stringify(key);
        let group = this.workouts.get(id);
        if (!group) {
            group = { key, first: recordOrder(row), count: 0, duration: 0, distance: empty(), total: empty(), active: empty() };
            this.workouts.set(id, group);
            this.check(byteLength(key) + byteLength(group.first));
        }
        this.retainFirst(group, row);
        group.count++;
        group.duration += Number(row.duration_seconds);
        for (const [field, target] of [['distance_meters', 'distance'], ['total_energy_kcal', 'total'], ['active_energy_kcal', 'active']] as const)
            if (row[field] !== null)
                add(group[target], Number(row[field]));
    }
    finish() {
        const combined = new Map<string, {
            key: string[];
            first: RecordOrder;
            stats: Stats;
        }>();
        for (const group of this.metrics.values()) {
            const key = group.key.slice(0, 3), id = JSON.stringify(key);
            let target = combined.get(id);
            if (!target) {
                target = { key, first: group.first, stats: empty() };
                combined.set(id, target);
            }
            if (this.compareRecords(group.first, target.first) < 0) target.first = group.first;
            merge(target.stats, group.preferred.count ? group.preferred : group.raw);
        }
        // v10's stable summary sort retains first appearance in public record order on ICU ties.
        // Use every raw row to establish that order, even when daily preference suppresses its value.
        const sorted = <T extends {key: string[]; first: RecordOrder}>(values: Iterable<T>) => [...values].sort((a, b) => a.key.join('\u0000').localeCompare(b.key.join('\u0000')) || this.compareRecords(a.first, b.first));
        return {
            metric_daily_summaries: sorted(combined.values()).map(({ key: [local_date, type, unit], stats: s }) => ({ local_date, type, unit, sample_count: s.count, total_value: s.sum, average_value: s.sum / s.count, minimum_value: s.min, maximum_value: s.max })),
            workout_daily_summaries: sorted(this.workouts.values()).map(g => ({ local_date: g.key[0], activity_type: g.key[1], workout_count: g.count, duration_minutes: g.duration / 60, distance_km: g.distance.count ? g.distance.sum / 1000 : null, total_energy_kcal: g.total.count ? g.total.sum : null, active_energy_kcal: g.active.count ? g.active.sum : null })),
        };
    }
    get groupKeyBytes() { return this.keyBytes; }
    get groupCount() { return this.metrics.size + this.workouts.size; }
}
