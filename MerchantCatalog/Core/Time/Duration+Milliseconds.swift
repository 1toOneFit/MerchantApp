extension Duration {
    /// Whole milliseconds, rounded down; a negative duration gives 0.
    var wholeMilliseconds: Int {
        let (seconds, attoseconds) = components
        return max(0, Int(seconds) * 1_000 + Int(attoseconds / 1_000_000_000_000_000))
    }
}
