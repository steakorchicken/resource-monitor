/// Fixed-capacity FIFO history. Appending beyond capacity drops the oldest element.
public struct RingBuffer<Element> {
    public let capacity: Int
    private var storage: [Element?]
    private var head = 0   // index of the oldest element
    public private(set) var count = 0

    public init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    public var isEmpty: Bool { count == 0 }
    public var isFull: Bool { count == capacity }

    public mutating func append(_ element: Element) {
        if count < capacity {
            storage[(head + count) % capacity] = element
            count += 1
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    public mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        head = 0
        count = 0
    }

    /// Elements from oldest to newest.
    public var elements: [Element] {
        (0..<count).compactMap { storage[(head + $0) % capacity] }
    }

    public var last: Element? {
        count == 0 ? nil : storage[(head + count - 1) % capacity]
    }
}

extension RingBuffer: Sequence {
    public func makeIterator() -> IndexingIterator<[Element]> { elements.makeIterator() }
}
