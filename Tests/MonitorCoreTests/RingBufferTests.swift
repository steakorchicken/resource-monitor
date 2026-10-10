import Testing
@testable import MonitorCore

@Test func ringBufferDropsOldest() {
    var buffer = RingBuffer<Int>(capacity: 3)
    for i in 1...5 { buffer.append(i) }
    #expect(buffer.elements == [3, 4, 5])
    #expect(buffer.last == 5)
    #expect(buffer.isFull)
}
