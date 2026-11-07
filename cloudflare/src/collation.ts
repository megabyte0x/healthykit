export class SourceCollation {
    readonly collator = new Intl.Collator('en-US', { usage: 'sort', sensitivity: 'variant', numeric: false, ignorePunctuation: false });
    private readonly encoder = new TextEncoder();
    compare = (left: string, right: string): number => {
        const order = this.collator.compare(left, right);
        if (order || left === right)
            return order;
        const a = this.encoder.encode(left), b = this.encoder.encode(right);
        for (let i = 0; i < Math.min(a.length, b.length); i++)
            if (a[i] !== b[i])
                return a[i] - b[i];
        return a.length - b.length;
    };
    key = (left: Record<string, any>, right: Record<string, any>): number => {
        if ('id' in left)
            return this.compare(left.device_id, right.device_id) || this.compare(left.id, right.id);
        return this.compare(left.export_id, right.export_id);
    };
    fingerprint() {
        const corpus = ['😀', 'a', 'A', 'å', 'ä', 'a b', 'a_b', 'a-b', 'a:b', 'a.b', 'a10', 'a2', 'æ', 'Æ', 'e', 'e\u0301', 'é', 'ss', 'ß', 'z', 'Z', '𐀀', '中文', '日本語'];
        return { options: this.collator.resolvedOptions(), order: corpus.sort(this.compare) };
    }
}
