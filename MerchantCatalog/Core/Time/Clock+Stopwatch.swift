extension Clock where Duration == Swift.Duration {
    /// Starts timing now; the returned closure reports the time elapsed since this call.
    ///
    /// Callable on `any Clock<Duration>`: the existential is opened for the call, so view models can
    /// store an injected clock (D-40) and still measure with its own instants.
    func stopwatch() -> () -> Swift.Duration {
        let start = now
        return { start.duration(to: self.now) }
    }
}
