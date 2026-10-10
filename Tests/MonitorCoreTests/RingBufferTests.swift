import Testing
@testable import MonitorCore

@Suite struct RingBufferTests {
    @Test func dropsOldestWhenFull() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for i in 1...5 { buffer.append(i) }
        #expect(buffer.elements == [3, 4, 5])
        #expect(buffer.last == 5)
        #expect(buffer.isFull)
    }

    @Test func partialFillKeepsOrder() {
        var buffer = RingBuffer<Int>(capacity: 4)
        buffer.append(1); buffer.append(2)
        #expect(buffer.elements == [1, 2])
        #expect(buffer.count == 2)
        #expect(!buffer.isFull)
    }

    @Test func removeAllResets() {
        var buffer = RingBuffer<Int>(capacity: 2)
        buffer.append(1); buffer.append(2); buffer.append(3)
        buffer.removeAll()
        #expect(buffer.isEmpty)
        #expect(buffer.last == nil)
        buffer.append(9)
        #expect(buffer.elements == [9])
    }
}
