//
//  ContentView.swift
//  Chessclock
//
//  Created by Red_wallen on 2026/6/4.
//

import SwiftUI
import AudioToolbox
import UIKit

// ====================
// 铃声选项
// ====================
struct RingtoneOption: Identifiable, Hashable {
    let id: String
    let soundID: SystemSoundID

    var name: String {
        switch id {
        case "alarm":       return String(localized: "闹钟声")
        case "bell":        return String(localized: "铃声")
        case "notification":return String(localized: "提示音")
        case "classic":     return String(localized: "经典")
        default:            return id
        }
    }
}

let availableRingtones: [RingtoneOption] = [
    RingtoneOption(id: "alarm",       soundID: 1005),
    RingtoneOption(id: "bell",        soundID: 1025),
    RingtoneOption(id: "notification",soundID: 1057),
    RingtoneOption(id: "classic",     soundID: 1304),
]

// ====================
// 加时选项
// ====================
struct IncrementTypeOption: Identifiable, Hashable {
    let id: String

    var name: String {
        switch id {
        case "none":      return String(localized: "无")
        case "fischer":   return String(localized: "费舍尔时间")
        case "bronstein": return String(localized: "布罗斯坦时间")
        default:          return id
        }
    }
}

let incrementTypes: [IncrementTypeOption] = [
    IncrementTypeOption(id: "none"),
    IncrementTypeOption(id: "fischer"),
    IncrementTypeOption(id: "bronstein"),
]

// 将时/分/秒转为总秒数
func totalSeconds(hours: Int, minutes: Int, seconds: Int) -> Double {
    return Double(hours * 3600 + minutes * 60 + seconds)
}

// 滑动条标签本地化辅助函数
func pickerHourLabel(_ h: Int) -> String {
    String(format: NSLocalizedString("picker_hour", value: "%d时", comment: ""), h)
}
func pickerMinuteLabel(_ m: Int) -> String {
    String(format: NSLocalizedString("picker_minute", value: "%d分", comment: ""), m)
}
func pickerSecondLabel(_ s: Int) -> String {
    String(format: NSLocalizedString("picker_second", value: "%d秒", comment: ""), s)
}



struct TimerView: View {

    // 是否跟随系统
    @AppStorage("followSystemTheme")
    private var followSystemTheme = true

    // 是否使用深色模式
    @AppStorage("darkMode")
    private var darkMode = false

    // ====================
    // 从设置读取时长配置
    // ====================
    @AppStorage("whiteHours")   private var whiteHours = 0
    @AppStorage("whiteMinutes") private var whiteMinutes = 10
    @AppStorage("whiteSeconds") private var whiteSeconds = 0

    @AppStorage("blackHours")   private var blackHours = 0
    @AppStorage("blackMinutes") private var blackMinutes = 10
    @AppStorage("blackSeconds") private var blackSeconds = 0

    // ====================
    // 从设置读取铃声
    // ====================
    @AppStorage("selectedRingtoneID")
    private var selectedRingtoneID = "alarm"

    // ====================
    // 时间显示格式
    // ====================
    @AppStorage("showHoursInTimer")
    private var showHoursInTimer = true

    // ====================
    // 加时设置
    // ====================
    @AppStorage("incrementType")
    private var incrementType = "none"
    @AppStorage("incrementSeconds")
    private var incrementSeconds = 0

    // 定义两个时间变量，分别代表双方
    @State private var timeA = 600.0
    @State private var timeB = 600.0

    // 记录当前是谁的回合 (true 是 A, false 是 B)
    @State private var isTurnA = true

    // 定时器
    @State private var timer: Timer? = nil

    // 开始时为暂停状态，用户需点击播放按钮开始计时
    @State private var isPaused = true

    // 记录双方是否已经响过铃（防止每 0.1 秒重复响铃）
    @State private var soundPlayedA = false
    @State private var soundPlayedB = false

    // 布罗斯坦计时：记录回合开始时的时间，用于计算封顶
    @State private var turnStartTimeA = 600.0
    @State private var turnStartTimeB = 600.0

    // 是否有一方计时结束
    var isTimeUp: Bool {
        (timeA <= 0 && soundPlayedA) || (timeB <= 0 && soundPlayedB)
    }

    var body: some View {
        VStack(spacing: 0) {

            // --- 上半部分：黑方时间（颠倒显示） ---
            VStack {
                Spacer()
                // 加时提示
                if incrementType != "none" {
                    Text("+\(incrementSeconds)s")
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(180))
                }
                Text(formatTime(timeB))
                    .font(.system(size: 70, weight: .bold, design: .monospaced))
                    .foregroundColor(isTurnA ? .red : .green)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.15))
                    )
                    .rotationEffect(.degrees(180))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
                if !isTimeUp { switchTurn(toA: true) }
            }

            // 中间区域：分割线 + 控制按钮
            ZStack {
                Divider()

                HStack(spacing: 30) {
                    // 暂停 / 继续按钮
                    Button {
                        if !isTimeUp { togglePause() }
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(isTimeUp ? Color.gray : Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .disabled(isTimeUp)
                    .opacity(isTimeUp ? 0.4 : 1.0)

                    // 重置按钮
                    Button {
                        resetTimer()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
            }

            // --- 下半部分：白方时间（正常显示） ---
            VStack {
                Spacer()
                // 加时提示
                if incrementType != "none" {
                    Text("+\(incrementSeconds)s")
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Text(formatTime(timeA))
                    .font(.system(size: 70, weight: .bold, design: .monospaced))
                    .foregroundColor(isTurnA ? .green : .red)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.15))
                    )
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
                if !isTimeUp { switchTurn(toA: false) }
            }
        }
        .background(Color.gray.opacity(0.1))
        .ignoresSafeArea()
        .onAppear {
            // 加载设置中的时长
            timeA = totalSeconds(hours: whiteHours, minutes: whiteMinutes, seconds: whiteSeconds)
            timeB = totalSeconds(hours: blackHours, minutes: blackMinutes, seconds: blackSeconds)
        }
        .onDisappear {
            // 离开计时页面时恢复自动熄屏
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // 切换回合的逻辑（含加时）
    func switchTurn(toA: Bool) {
        // 给刚完成移动的一方加时
        if incrementType != "none" && incrementSeconds > 0 {
            if isTurnA {
                // A 刚走完，给 A 加时
                applyIncrement(to: &timeA, startTime: turnStartTimeA)
            } else {
                // B 刚走完，给 B 加时
                applyIncrement(to: &timeB, startTime: turnStartTimeB)
            }
        }

        isTurnA = toA
        // 记录新回合开始时的时间（布罗斯坦封顶用）
        if toA {
            turnStartTimeA = timeA
        } else {
            turnStartTimeB = timeB
        }
        startTimer()
        isPaused = false
    }

    // 加时计算
    func applyIncrement(to time: inout Double, startTime: Double) {
        let inc = Double(incrementSeconds)
        switch incrementType {
        case "fischer":
            time += inc
        case "bronstein":
            // 布罗斯坦：时间不能超过回合开始时的值
            time = min(startTime, time + inc)
        default:
            break
        }
    }

    // 启动或重置定时器
    func startTimer() {
        // 先停止旧的定时器
        timer?.invalidate()

        // 倒计时开始后取消自动熄屏
        UIApplication.shared.isIdleTimerDisabled = true

        // 创建新的定时器，每 0.1 秒执行一次
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if isTurnA {
                if timeA > 0 {
                    timeA -= 0.1
                } else if !soundPlayedA {
                    playSelectedRingtone()
                    soundPlayedA = true
                    // 倒计时结束，自动暂停
                    pauseTimer()
                    isPaused = true
                }
            } else {
                if timeB > 0 {
                    timeB -= 0.1
                } else if !soundPlayedB {
                    playSelectedRingtone()
                    soundPlayedB = true
                    // 倒计时结束，自动暂停
                    pauseTimer()
                    isPaused = true
                }
            }
        }
    }

    // 播放选中的铃声
    func playSelectedRingtone() {
        let soundID = availableRingtones.first { $0.id == selectedRingtoneID }?.soundID ?? 1005
        AudioServicesPlayAlertSound(soundID)
    }

    // 格式化时间的辅助函数
    func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        if showHoursInTimer {
            let h = total / 3600
            let m = (total % 3600) / 60
            let s = total % 60
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            // 不显示小时时，将小时换算为分钟
            let m = total / 60
            let s = total % 60
            return String(format: "%02d:%02d", m, s)
        }
    }

    // 暂停功能
    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        // 暂停时恢复自动熄屏
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // 暂停 / 继续 切换
    func togglePause() {
        if isPaused {
            startTimer()
        } else {
            pauseTimer()
        }
        isPaused.toggle()
    }

    // 重置功能
    func resetTimer() {
        pauseTimer()
        timeA = totalSeconds(hours: whiteHours, minutes: whiteMinutes, seconds: whiteSeconds)
        timeB = totalSeconds(hours: blackHours, minutes: blackMinutes, seconds: blackSeconds)
        turnStartTimeA = timeA
        turnStartTimeB = timeB
        isTurnA = true
        isPaused = true      // 重置后回到暂停状态
        soundPlayedA = false
        soundPlayedB = false
    }
}

// 应用的真正主入口，负责显示底部 TabBar
struct ContentView: View {
    
    @AppStorage("followSystemTheme")
    private var followSystemTheme = true

    @AppStorage("darkMode")
    private var darkMode = false
    
    var body: some View {
        TabView {
            // 第一个标签页：计时
            TimerView()
                .tabItem {
                    Label("计时", systemImage: "timer") // 图标+文字
                }
            
            // 第二个标签页：设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape") // 图标+文字
                }
        }
        .tint(.blue) // 设置选中时的主题色为蓝色
        
        .preferredColorScheme(
            followSystemTheme
            ? nil
            : (darkMode ? .dark : .light)
        )
    }
}

struct SettingsView: View {

    // ====================
    // 外观设置
    // ====================
    @AppStorage("followSystemTheme")
    private var followSystemTheme = true

    @AppStorage("darkMode")
    private var darkMode = false

    // ====================
    // 白方时间
    // ====================
    @AppStorage("whiteHours") var whiteHours = 0
    @AppStorage("whiteMinutes") var whiteMinutes = 10
    @AppStorage("whiteSeconds") var whiteSeconds = 0

    // ====================
    // 黑方时间
    // ====================
    @AppStorage("blackHours") var blackHours = 0
    @AppStorage("blackMinutes") var blackMinutes = 10
    @AppStorage("blackSeconds") var blackSeconds = 0

    // ====================
    // 控制滚轮展开/收起（同一时刻只允许一方展开）
    // ====================
    @State private var isWhiteExpanded = false
    @State private var isBlackExpanded = false

    // ====================
    // 铃声选择
    // ====================
    @AppStorage("selectedRingtoneID")
    private var selectedRingtoneID = "alarm"

    // ====================
    // 加时设置
    // ====================
    @AppStorage("incrementType")
    private var incrementType = "none"
    @AppStorage("incrementSeconds")
    private var incrementSeconds = 0

    @State private var isIncrementExpanded = false
    @State private var showIncrementInfo = false

    // ====================
    // 计时显示
    // ====================
    @AppStorage("showHoursInTimer")
    private var showHoursInTimer = true

    // 格式化时长显示
    func formatDuration(hours: Int, minutes: Int, seconds: Int) -> String {
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var body: some View {

        NavigationStack {

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ====================
                    // 时长设置
                    // ====================
                    VStack(alignment: .leading, spacing: 0) {
                        Text("时长设置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                            .padding(.bottom, 4)

                        VStack(spacing: 0) {

                            // ---------- 白方时间 ----------
                            VStack(spacing: 0) {
                                HStack {
                                    Text("白方时间")
                                    Spacer()
                                    Text(formatDuration(hours: whiteHours, minutes: whiteMinutes, seconds: whiteSeconds))
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isWhiteExpanded.toggle()
                                        if isBlackExpanded { isBlackExpanded = false }
                                        if isIncrementExpanded { isIncrementExpanded = false }
                                    }
                                }

                                if isWhiteExpanded {
                                    HStack(spacing: 0) {
                                        Picker(String(localized: "时"), selection: $whiteHours) {
                                            ForEach(0..<24) { Text(pickerHourLabel($0)).tag($0) }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(maxWidth: .infinity)
                                        .clipped()

                                        Picker(String(localized: "分"), selection: $whiteMinutes) {
                                            ForEach(0..<60) { Text(pickerMinuteLabel($0)).tag($0) }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(maxWidth: .infinity)
                                        .clipped()

                                        Picker(String(localized: "秒"), selection: $whiteSeconds) {
                                            ForEach(0..<60) { Text(pickerSecondLabel($0)).tag($0) }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                    }
                                    .frame(height: 120)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }

                            Divider().padding(.leading)

                            // ---------- 黑方时间 ----------
                            VStack(spacing: 0) {
                                HStack {
                                    Text("黑方时间")
                                    Spacer()
                                    Text(formatDuration(hours: blackHours, minutes: blackMinutes, seconds: blackSeconds))
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isBlackExpanded.toggle()
                                        if isWhiteExpanded { isWhiteExpanded = false }
                                        if isIncrementExpanded { isIncrementExpanded = false }
                                    }
                                }

                                if isBlackExpanded {
                                    HStack(spacing: 0) {
                                        Picker(String(localized: "时"), selection: $blackHours) {
                                            ForEach(0..<24) { Text(pickerHourLabel($0)).tag($0) }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(maxWidth: .infinity)
                                        .clipped()

                                        Picker(String(localized: "分"), selection: $blackMinutes) {
                                            ForEach(0..<60) { Text(pickerMinuteLabel($0)).tag($0) }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(maxWidth: .infinity)
                                        .clipped()

                                        Picker(String(localized: "秒"), selection: $blackSeconds) {
                                            ForEach(0..<60) { Text(pickerSecondLabel($0)).tag($0) }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                    }
                                    .frame(height: 120)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)

                    // ====================
                    // 加时设置
                    // ====================
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Text("加时设置")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button {
                                showIncrementInfo = true
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.leading)
                        .padding(.bottom, 4)

                        VStack(spacing: 0) {
                            // 标签行
                            HStack {
                                Text("加时")
                                Spacer()
                                Text(incrementLabel)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isIncrementExpanded.toggle()
                                    if isWhiteExpanded { isWhiteExpanded = false }
                                    if isBlackExpanded { isBlackExpanded = false }
                                }
                            }

                            // 展开区域：类型选择 + 秒数滚轮
                            if isIncrementExpanded {
                                VStack(spacing: 0) {
                                    // 类型选择按钮
                                    HStack(spacing: 12) {
                                        ForEach(incrementTypes) { type in
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    incrementType = type.id
                                                }
                                            } label: {
                                                Text(type.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(incrementType == type.id ? .white : .primary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        incrementType == type.id
                                                            ? Color.blue
                                                            : Color(.systemGray5)
                                                    )
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                    .padding(.bottom, incrementType == "none" ? 12 : 0)

                                    // 秒数滚轮（仅非"无"时显示）
                                    if incrementType != "none" {
                                        HStack(spacing: 0) {
                                            Spacer()
                                            Picker(String(localized: "秒"), selection: $incrementSeconds) {
                                                ForEach(0..<60) { Text(pickerSecondLabel($0)).tag($0) }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(width: 120, height: 120)
                                            .clipped()
                                            Spacer()
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .alert("加时规则说明", isPresented: $showIncrementInfo) {
                            Button("知道了") { }
                        } message: {
                            Text("费舍尔时间 (Fischer)：每步棋后，加时秒数直接加到剩余时间上。\n\n布罗斯坦时间 (Bronstein)：每步棋后，加时秒数加到剩余时间上，但不能超过该回合开始时的剩余时间。")
                        }
                    }
                    .padding(.horizontal)

                    // ====================
                    // 铃声设置
                    // ====================
                    VStack(alignment: .leading, spacing: 0) {
                        Text("铃声设置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                            .padding(.bottom, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(availableRingtones.enumerated()), id: \.element.id) { index, ringtone in
                                Button {
                                    selectedRingtoneID = ringtone.id
                                    AudioServicesPlayAlertSound(ringtone.soundID)
                                } label: {
                                    HStack {
                                        Text(ringtone.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedRingtoneID == ringtone.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < availableRingtones.count - 1 {
                                    Divider().padding(.leading)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)

                    // ====================
                    // 计时显示
                    // ====================
                    VStack(alignment: .leading, spacing: 0) {
                        Text("计时显示")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                            .padding(.bottom, 4)

                        VStack(spacing: 0) {
                            Toggle("显示小时（时:分:秒）", isOn: $showHoursInTimer)
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)

                    // ====================
                    // 外观设置
                    // ====================
                    VStack(alignment: .leading, spacing: 0) {
                        Text("外观")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                            .padding(.bottom, 4)

                        VStack(spacing: 0) {
                            Toggle("跟随系统", isOn: $followSystemTheme)
                                .padding(.horizontal)
                                .padding(.vertical, 10)

                            Divider().padding(.leading)

                            Toggle("深色模式", isOn: $darkMode)
                                .disabled(followSystemTheme)
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("设置")
        }
    }

    // 加时标签文字
    var incrementLabel: String {
        guard let type = incrementTypes.first(where: { $0.id == incrementType }) else { return String(localized: "无") }
        if incrementType == "none" {
            return String(localized: "无")
        } else {
            let format = NSLocalizedString("increment_label", value: "%@ +%ds", comment: "")
            return String(format: format, type.name, incrementSeconds)
        }
    }
}

#Preview {
    ContentView()
}
