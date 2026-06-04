import Foundation

// Codex hatch-pet 主状态保持原 9 状态不变，row 9-10 为扩展动作
// Row 0: idle | 1: running-right | 2: running-left
// Row 3: waving | 4: jumping | 5: failed
// Row 6: waiting | 7: running | 8: review
// Row 9: sunburn-shy | Row 10: sunburn-swim
// Spritesheet 行对应关系（12列 × 11行，每格 192×208）
// Row 0: idle      Row 1: running-right  Row 2: running-left
// Row 3: waving    Row 4: jumping        Row 5: failed
// Row 6: waiting   Row 7: running        Row 8: review
// Row 9: sunburn-shy  Row 10: sunburn-swim
enum PetState: String, CaseIterable {
    case idle        // 待机 (row 0)
    case walking     // 漫步，内部用，实际切 row1/2
    case waving      // 挥手 (row 3)
    case jumping     // 跳跃，预留 (row 4)
    case failed      // 报错崩了 (row 5)
    case waiting     // 等待批准 (row 6)
    case thinking    // Qoder 思考中 = waiting 行复用 (row 6)
    case coding      // 正在生成代码 (row 7)
    case review      // 完成检查 (row 8)
    case sunburn     // W 坐姿，外套半脱 (row 9)
    case sunburnSwim // 同姿势，运动泳装 (row 10)

    var displayName: String {
        switch self {
        case .idle:     return "😊 待机"
        case .walking:  return "🚶 漫步"
        case .waving:   return "👋 打招呼"
        case .jumping:  return "🎵 跳跃"
        case .failed:   return "😵 报错"
        case .waiting:  return "🙋 等待批准"
        case .thinking: return "🤔 思考中"
        case .coding:   return "⌨️ 编码中"
        case .review:   return "🎉 完成"
        case .sunburn:  return "☀️ 日晒"
        case .sunburnSwim: return "☀️ 日晒换装"
        }
    }

    var animationConfig: AnimationConfig {
        switch self {
        case .idle:     return AnimationConfig(row: 0, frameCount: 6, fps: 8)
        case .walking:  return AnimationConfig(row: 1, frameCount: 8, fps: 10)
        case .waving:   return AnimationConfig(row: 3, frameCount: 4, fps: 8)
        case .jumping:  return AnimationConfig(row: 4, frameCount: 5, fps: 10)
        case .failed:   return AnimationConfig(row: 5, frameCount: 8, fps: 5)
        case .waiting:  return AnimationConfig(row: 6, frameCount: 6, fps: 5)
        case .thinking: return AnimationConfig(row: 6, frameCount: 6, fps: 6)
        case .coding:   return AnimationConfig(row: 7, frameCount: 6, fps: 9)
        case .review:   return AnimationConfig(row: 8, frameCount: 6, fps: 7)
        case .sunburn:     return AnimationConfig(row: 9,  frameCount: 12, fps: 6)
        case .sunburnSwim: return AnimationConfig(row: 10, frameCount: 12, fps: 6)
        }
    }
}

struct AnimationConfig {
    let row: Int
    let frameCount: Int
    let fps: Double
}
