import Foundation
import SwiftUI


enum WatchType: String, CaseIterable, Hashable, Codable, Identifiable {
    case none, appleWatch, watlaa
    var id: String { rawValue }
    var name: String {
        switch self {
        case .none:       return "Any"
        case .appleWatch: return AppleWatch.name
        case .watlaa:     return Watlaa.name
        }
    }
    var type: AnyClass {
        switch self {
        case .none:       return Watch.self
        case .appleWatch: return AppleWatch.self
        case .watlaa:     return Watlaa.self
        }
    }
}


class Watch: Device {
    override class var type: DeviceType { DeviceType.watch(.none) }
    var transmitter: Transmitter? = Transmitter()
}


class AppleWatch: Watch {
    override class var type: DeviceType { DeviceType.watch(.appleWatch) }
    override class var name: String { "Apple Watch" }
}


class Watlaa: Watch {
    override class var type: DeviceType { DeviceType.watch(.watlaa) }
    override class var name: String { "Watlaa" }

    enum UUID: String, CustomStringConvertible, CaseIterable {
        case data           = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataWrite      = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
        case dataRead       = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
        case legacyData     = "00001010-1212-EFDE-0137-875F45AC0113"
        case legacyDataRead = "00001011-1212-EFDE-0137-875F45AC0113"
        case bridgeStatus   = "00001012-1212-EFDE-0137-875F45AC0113"
        case lastGlucose    = "00001013-1212-EFDE-0137-875F45AC0113"
        case calibration    = "00001014-1212-EFDE-0137-875F45AC0113"
        case glucoseUnit    = "00001015-1212-EFDE-0137-875F45AC0113"
        case alerts         = "00001016-1212-EFDE-0137-875F45AC0113"
        case unknown1       = "00001017-1212-EFDE-0137-875F45AC0113"
        case unknown2       = "00001018-1212-EFDE-0137-875F45AC0113"

        var description: String {
            switch self {
            case .data:           return "data"
            case .dataRead:       return "data read"
            case .dataWrite:      return "data write"
            case .legacyData:     return "data (legacy)"
            case .legacyDataRead: return "raw glucose data (legacy)"
            case .bridgeStatus:   return "bridge connection status"
            case .lastGlucose:    return "last glucose raw value"
            case .calibration:    return "calibration"
            case .glucoseUnit:    return "glucose unit"
            case .alerts:         return "alerts settings"
            case .unknown1:       return "unknown 1"
            case .unknown2:       return "unknown 2 (sensor serial)"
            }
        }
    }

    override class var dataServiceUUID: String             { UUID.data.rawValue }
    override class var dataWriteCharacteristicUUID: String { UUID.dataWrite.rawValue }
    override class var dataReadCharacteristicUUID: String  { UUID.dataRead.rawValue }
    class var legacyDataServiceUUID: String                { UUID.legacyData.rawValue }
    class var legacyDataReadCharacteristicUUID: String     { UUID.legacyDataRead.rawValue }

    // Same as MiaoMiao
    enum ResponseType: UInt8, CustomStringConvertible {
        case dataPacket = 0x28
        case newSensor  = 0x32
        case noSensor   = 0x34
        case frequencyChange = 0xD1

        var description: String {
            switch self {
            case .dataPacket:      return "data packet"
            case .newSensor:       return "new sensor"
            case .noSensor:        return "no sensor"
            case .frequencyChange: return "frequency change"
            }
        }
    }

    enum BridgeStatus: UInt8, CustomStringConvertible {
        case notConnetced = 0x00
        case connectedInactiveSensor
        case connectedActiveSensor
        case unknown

        var description: String {
            switch self {
            case .notConnetced:            return "not connected"
            case .connectedInactiveSensor: return "connected, inactive sensor"
            case .connectedActiveSensor:   return "connected, active sensor"
            case .unknown:                 return "unknown"
            }
        }
    }

    var bridgeStatus: BridgeStatus = .unknown
    var slope: Float = 0.0
    var intercept: Float = 0.0
    var lastGlucose: Int = 0
    var lastGlucoseAge: Int = 0
    var unit: GlucoseUnit = .mgdl

    var lastReadingDate: Date = Date()

    func readValue(for uuid: UUID) {
        peripheral?.readValue(for: characteristics[uuid.rawValue]!)
        main.debugLog("\(name): requested value for \(uuid)")
    }


    // Same as MiaoMiao
    override func readCommand(interval: Int = 5) -> [UInt8] {
        var command = [UInt8(0xF0)]
        if [1, 3].contains(interval) {
            command.insert(contentsOf: [0xD1, UInt8(interval)], at: 0)
        }
        return command
    }


    override func read(_ data: Data, for uuid: String) {

        let description = UUID(rawValue: uuid)?.description ?? uuid
        main.log("\(name): received value for \(description) characteristic")

        switch UUID(rawValue: uuid) {


        // Same as MiaoMiao
        case .dataRead:
            let bridge = transmitter!
            let bridgeName = "\(transmitter!.name) + \(name)"

            let response = ResponseType(rawValue: data[0])
            if bridge.buffer.count == 0 {
                main.log("\(bridgeName) response: \(response?.description ?? "unknown") (0x\(data[0...0].hex))")
            }
            if data.count == 1 {
                if response == .noSensor {
                    main.info("\n\n\(bridgeName): no sensor")
                }
                // TODO: prompt the user and allow writing the command 0xD301 to change sensor
                if response == .newSensor {
                    main.info("\n\n\(bridgeName): detected a new sensor")
                }
            } else if data.count == 2 {
                if response == .frequencyChange {
                    if data[1] == 0x01 {
                        main.log("\(bridgeName): success changing frequency")
                    } else {
                        main.log("\(bridgeName): failed to change frequency")
                    }
                }
            } else {
                if bridge.sensor == nil {
                    bridge.sensor = Sensor(transmitter: bridge)
                    main.app.sensor = bridge.sensor
                }
                if bridge.buffer.count == 0 { bridge.sensor!.lastReadingDate = main.app.lastReadingDate }
                bridge.buffer.append(data)
                main.log("\(bridgeName): partial buffer count: \(bridge.buffer.count)")
                if bridge.buffer.count >= 363 {
                    main.log("\(bridgeName): data count: \(Int(bridge.buffer[1]) << 8 + Int(bridge.buffer[2]))")

                    bridge.battery  = Int(bridge.buffer[13])
                    bridge.firmware = bridge.buffer[14...15].hex
                    bridge.hardware = bridge.buffer[16...17].hex
                    main.log("\(bridgeName): battery: \(battery), firmware: \(firmware), hardware: \(hardware)")

                    bridge.sensor!.age = Int(bridge.buffer[3]) << 8 + Int(bridge.buffer[4])
                    bridge.sensor!.uid = Data(bridge.buffer[5...12])
                    main.log("\(bridgeName): sensor age: \(bridge.sensor!.age) minutes (\(String(format: "%.1f", Double(bridge.sensor!.age)/60/24)) days), patch uid: \(bridge.sensor!.uid.hex), serial number: \(bridge.sensor!.serial)")

                    if bridge.buffer.count > 363 {
                        bridge.sensor!.patchInfo = Data(bridge.buffer[363...368])
                        main.log("\(bridgeName): patch info: \(bridge.sensor!.patchInfo.hex)")
                    } else {
                        bridge.sensor!.patchInfo = Data([0xDF, 0x00, 0x00, 0x01, 0x01, 0x02])
                    }
                    bridge.sensor!.fram = Data(bridge.buffer[18 ..< 362])
                    readSetup()
                    main.info("\n\n\(bridge.sensor!.type)  +  \(bridgeName)")
                }
            }


        case .legacyDataRead:

            let bridge = transmitter!
            let bridgeName = "\(transmitter!.name) + \(name)"

            if bridge.sensor == nil {
                if main.app.sensor != nil {
                    bridge.sensor = main.app.sensor
                } else {
                    bridge.sensor = Sensor(transmitter: bridge)
                    main.app.sensor = bridge.sensor
                }
            }
            if bridge.buffer.count == 0 { bridge.sensor!.lastReadingDate = main.app.lastReadingDate }
            lastReadingDate = main.app.lastReadingDate
            bridge.buffer.append(data)
            main.log("\(bridgeName): partial buffer count: \(bridge.buffer.count)")

            if bridge.buffer.count == 344 {
                let fram = bridge.buffer[..<344]
                bridge.sensor!.fram = Data(fram)
                readSetup()
                main.info("\n\n\(bridge.sensor!.type)  +  \(bridgeName)")
            }


        case .lastGlucose:
            let value = Int(data[1]) << 8 + Int(data[0])
            let age   = Int(data[3]) << 8 + Int(data[2])
            lastGlucose = value
            lastGlucoseAge = age
            main.log("\(name): last raw glucose: \(value), age: \(age) minutes")

        case .calibration:
            let slope:     Float = Data(data[0...3]).withUnsafeBytes { $0.load(as: Float.self) }
            let intercept: Float = Data(data[4...7]).withUnsafeBytes { $0.load(as: Float.self) }
            self.slope = slope
            self.intercept = intercept
            main.log("\(name): slope: \(slope), intercept: \(intercept)")

        case .glucoseUnit:
            if let unit = GlucoseUnit(rawValue: GlucoseUnit.allCases[Int(data[0])].rawValue) {
                main.log("\(name): glucose unit: \(unit)")
                self.unit = unit
            }

        case .bridgeStatus:
            bridgeStatus = data[0] < BridgeStatus.unknown.rawValue ? BridgeStatus(rawValue: data[0])! : .unknown
            main.log("\(name): transmitter status: \(bridgeStatus.description)")

        case .alerts:
            let high: Float = Data(data[0...3]).withUnsafeBytes { $0.load(as: Float.self) }
            let low:  Float = Data(data[4...7]).withUnsafeBytes { $0.load(as: Float.self) }
            let bridgeConnection: Int = Int(data[9]) << 8 + Int(data[8])
            let lowSnooze: Int  = Int(data[11]) << 8 + Int(data[10])
            let highSnooze: Int = Int(data[13]) << 8 + Int(data[12])
            let signals: UInt8 = data[14]
            let sensorLostVibration: Bool = (signals >> 3) & 1 == 1
            let glucoseVibration: Bool    = (signals >> 1) & 1 == 1

            main.log("\(name): alerts: high: \(high), low: \(low), bridge connection: \(bridgeConnection) minutes, low snooze: \(lowSnooze) minutes, high snooze: \(highSnooze) minutes, sensor lost vibration: \(sensorLostVibration), glucose vibration: \(glucoseVibration)")

        case .unknown2:
            var sensorSerial = data.string
            if data[0] == 0 {
                sensorSerial = data.hex
            }
            transmitter?.serial = sensorSerial
            main.log("\(name): sensor serial number: \(sensorSerial)")

        default:
            break
        }
    }


    func readSetup() {
        readValue(for: .calibration)
        readValue(for: .glucoseUnit)
        readValue(for: .lastGlucose)
        readValue(for: .bridgeStatus)
        readValue(for: .alerts)
        readValue(for: .unknown2) // sensor serial
    }
}


struct WatlaaDetailsView: View {

    var device: Device

    var body: some View {
        VStack(spacing: 20) {
            Text("Transmitter status: \((device as! Watlaa).bridgeStatus.description)")
            Text("Serial number: \(device.serial)")
            Text("Glucose unit: \((device as! Watlaa).unit.description)")
            Text("Calibration intercept: \((device as! Watlaa).intercept)")
            Text("Calibration slope: \((device as! Watlaa).slope)")

            Text("Sensor serial: \((device as! Watlaa).transmitter!.serial)")


        }
    }
}


// TODO

//struct Watch_Previews: PreviewProvider {
//    static var previews: some View {
//        Text("TODO")
//    }
//}
