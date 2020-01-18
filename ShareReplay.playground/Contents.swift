//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport
import Combine

PlaygroundPage.current.needsIndefiniteExecution = true

// https://github.com/tcldr/Entwine/blob/8be24a59bc91410bb29e84b1c4ae35398a5839c8/Sources/Entwine/Operators/ReplaySubject.swift
// https://forums.swift.org/t/combine-equivalent-to-rxswift-sharereplay-operators/27916/3

fileprivate final class ReplaySubjectSubscription<Output, Failure: Error>: Subscription {
    fileprivate weak var parent: ReplaySubject<Output, Failure>?
    fileprivate let downstream: AnySubscriber<Output, Failure>
    fileprivate var isCompleted: Bool { parent == nil }
    fileprivate var demand: Subscribers.Demand = .none

    init(parent: ReplaySubject<Output, Failure>, downstream: AnySubscriber<Output, Failure>) {
        self.parent = parent
        self.downstream = downstream
    }

    // Tells a publisher that it may send more values to the subscriber.
    func request(_ demand: Subscribers.Demand) {
        self.demand += demand
        parent?.acknowledgeDownstreamDemand()
    }

    func cancel() {
        parent = nil
    }

    fileprivate func receive(_ value: Output) {
        guard !isCompleted, demand > 0 else { return }

        demand += downstream.receive(value)
        demand -= 1
    }

    fileprivate func receive(completion: Subscribers.Completion<Failure>) {
        guard !isCompleted else { return }
        parent = nil
        downstream.receive(completion: completion)
    }

    fileprivate func replayInputs(_ values: [Output], completion: Subscribers.Completion<Failure>?) {
        guard !isCompleted else { return }
        values.forEach { value in receive(value) }
        if let completion = completion { receive(completion: completion) }
    }
}

final class ReplaySubject<Output, Failure: Error>: Subject {
    private var buffer = [Output]()
    private let maxValues: Int
    private var subscriptions = [ReplaySubjectSubscription<Output, Failure>]()
    private var completion: Subscribers.Completion<Failure>?

    private var upstreamSubscriptions: [Subscription] = []
    private var hasAnyDownstreamDemand = false

    init(maxValues: Int = 0) {
        self.maxValues = maxValues
    }

    /// Provides this Subject an opportunity to establish demand for any new upstream subscriptions (say via, ```Publisher.subscribe<S: Subject>(_: Subject)`
    func send(subscription: Subscription) {
        dump("upstream \(subscription)!")
        upstreamSubscriptions.append(subscription)
        if hasAnyDownstreamDemand {
            subscription.request(.unlimited)
        }
    }

    /// Sends a value to the subscriber.
    ///
    /// - Parameter value: The value to send.
    func send(_ value: Output) {
        print("send \(value)")
        buffer.append(value)
        buffer = buffer.suffix(maxValues)
        subscriptions.forEach { $0.receive(value) }
    }

    /// Sends a completion signal to the subscriber.
    ///
    /// - Parameter completion: A `Completion` instance which indicates whether publishing has finished normally or failed with an error.
    func send(completion: Subscribers.Completion<Failure>) {
        subscriptions.forEach { subscription in subscription.receive(completion: completion) }
    }

    /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
    ///
    /// - SeeAlso: `subscribe(_:)`
    /// - Parameters:
    ///     - subscriber: The subscriber to attach to this `Publisher`.
    ///                   once attached it can begin to receive values.
    func receive<Downstream: Subscriber>(subscriber: Downstream) where Downstream.Failure == Failure, Downstream.Input == Output {
        if let completion = completion {
            subscriber.receive(subscription: Subscriptions.empty)
            subscriber.receive(completion: completion)
            return
        }

        let subscription = ReplaySubjectSubscription<Output, Failure>(parent: self, downstream: AnySubscriber(subscriber))
        subscriber.receive(subscription: subscription)
        subscriptions.append(subscription)
        subscription.replayInputs(buffer, completion: completion)
    }

    fileprivate func acknowledgeDownstreamDemand() {
        dump("Requested demand!")
        guard !hasAnyDownstreamDemand else { return }
        hasAnyDownstreamDemand = true
        for subscription in upstreamSubscriptions {
            subscription.request(.unlimited)
        }
    }
}

extension Publisher {

/// Applies a closure to create a subject that delivers elements to subscribers.
///
/// Use a multicast publisher when you have multiple downstream subscribers, but you want upstream publishers to only process one `receive(_:)` call per event.
/// In contrast with `multicast(subject:)`, this method produces a publisher that creates a separate Subject for each subscriber.
/// - Parameter createSubject: A closure to create a new Subject each time a subscriber attaches to the multicast publisher.
    /**
     * Returns a {@link ConnectableObservable} that shares a single subscription to the source ObservableSource that
     * replays at most {@code bufferSize} items emitted by that ObservableSource. A Connectable ObservableSource resembles
     * an ordinary ObservableSource, except that it does not begin emitting items when it is subscribed to, but only
     * when its {@code connect} method is called.
     * <p>
     * Note that due to concurrency requirements, {@code replay(bufferSize)} may hold strong references to more than
     * {@code bufferSize} source emissions.
     * <p>
     * <img width="640" height="445" src="https://raw.github.com/wiki/ReactiveX/RxJava/images/rx-operators/replay.o.n.png" alt="">
     * <dl>
     *  <dt><b>Scheduler:</b></dt>
     *  <dd>This version of {@code replay} does not operate by default on a particular {@link Scheduler}.</dd>
     * </dl>
     *
     * @param bufferSize
     *            the buffer size that limits the number of items that can be replayed
     * @return a {@link ConnectableObservable} that shares a single subscription to the source ObservableSource and
     *         replays at most {@code bufferSize} items emitted by that ObservableSource
     * @see <a href="http://reactivex.io/documentation/operators/replay.html">ReactiveX operators documentation: Replay</a>
     */
    func replay(_ bufferSize: Int) -> AnyPublisher<Self.Output, Self.Failure> {
        return multicast(subject: ReplaySubject(maxValues: bufferSize)).autoconnect().eraseToAnyPublisher()
    }
}

var cancellables: [AnyCancellable] = []
let input = PassthroughSubject<Int, Never>() // Publishers.Sequence<[Int], Never>(sequence: [1, 2, 3])
let output = input.replay(1)
output.output(at: 1).sink(receiveCompletion: { _ in print("1: completion") }, receiveValue: { value in
    print("1: value \(value)")
}).store(in: &cancellables)

input.send(1)
input.send(2)

DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    output.sink(receiveCompletion: { _ in print("2: completion") }, receiveValue: { value in
        print("2: value \(value)")
    }).store(in: &cancellables)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    input.send(3)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    output.sink(receiveCompletion: { _ in print("3: completion") }, receiveValue: { value in
        print("3: value \(value)")
    }).store(in: &cancellables)
}
