import SwiftUI
import UIKit
import os

enum DuoPlayerPose: Equatable {
    case unavailable
    case closed
    case openFull
    case book
    case tabletop
    case tent
    case handheld
}

@MainActor
final class DuoPlayerPostureModel: ObservableObject {
    @Published private(set) var pose: DuoPlayerPose = .unavailable
    @Published private(set) var hingeAngleDegrees: Double?

    func update(pose: DuoPlayerPose, hingeAngleDegrees: Double?) {
        guard self.pose != pose || self.hingeAngleDegrees != hingeAngleDegrees else { return }
        self.pose = pose
        self.hingeAngleDegrees = hingeAngleDegrees
    }
}

struct DuoHingeObserver: UIViewRepresentable {
    @ObservedObject var model: DuoPlayerPostureModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.onLayout = { [weak coordinator = context.coordinator] view in
            coordinator?.layoutDidChange(in: view)
        }
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        context.coordinator.model = model
        context.coordinator.layoutDidChange(in: view)
    }

    final class ProbeView: UIView {
        var onLayout: ((UIView) -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?(self)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onLayout?(self)
        }
    }

    @MainActor
    final class Coordinator {
        var model: DuoPlayerPostureModel
        private var helper: AnyObject?

        init(model: DuoPlayerPostureModel) {
            self.model = model
        }

        func attach(to view: UIView) {
            guard #available(iOS 27.1, *) else {
                model.update(pose: .unavailable, hingeAngleDegrees: nil)
                return
            }
            helper = HingeHelper(view: view, modelProvider: { [weak self] in self?.model })
        }

        func layoutDidChange(in view: UIView) {
            guard #available(iOS 27.1, *), let helper = helper as? HingeHelper else { return }
            helper.layoutDidChange()
        }
    }
}

@available(iOS 27.1, *)
@MainActor
private final class HingeHelper {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "DJHUB",
        category: "DuoHinge"
    )

    private weak var view: UIView?
    private let modelProvider: () -> DuoPlayerPostureModel?
    private var hingeStatus: UIHinge.Status?
    private var angleRadians: CGFloat?
    private var interaction: UIHingeInteraction?

    init(view: UIView, modelProvider: @escaping () -> DuoPlayerPostureModel?) {
        self.view = view
        self.modelProvider = modelProvider
        let interaction = UIHingeInteraction { [weak self] _, update in
            self?.hingeStatus = update.hinge?.status
            self?.angleRadians = update.hinge?.angle
            self?.publish()
        }
        self.interaction = interaction
        view.addInteraction(interaction)
    }

    func layoutDidChange() {
        publish()
    }

    private func publish() {
        guard let view, let model = modelProvider() else { return }
        guard let hingeStatus else {
            model.update(pose: .unavailable, hingeAngleDegrees: nil)
            return
        }

        let bounds = view.bounds
        let isLandscape = bounds.width > bounds.height
        let divisions = view.reservedRegions(kind: .division).filter(\.isActive)
        let division = divisions.max { lhs, rhs in
            lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
        }
        let angleDegrees = angleRadians.map { Double($0 * 180 / .pi) }

        let pose: DuoPlayerPose
        switch hingeStatus {
        case .closed:
            pose = .closed
        case .fullyOpen:
            pose = .openFull
        case .partiallyOpen:
            if let division {
                pose = division.frame.width >= division.frame.height ? .tabletop : .book
            } else if let angleDegrees, angleDegrees < 90 {
                pose = .book
            } else if isLandscape, (angleDegrees ?? 120) < 165 {
                pose = .tent
            } else {
                pose = .handheld
            }
        case .unknown:
            pose = .unavailable
        @unknown default:
            pose = .unavailable
        }

        let divisionDescription = division.map { region in
            String(
                format: "x=%.1f y=%.1f w=%.1f h=%.1f",
                region.frame.origin.x,
                region.frame.origin.y,
                region.frame.width,
                region.frame.height
            )
        } ?? "none"
        Self.logger.debug(
            "status=\(String(describing: hingeStatus), privacy: .public) angle=\(angleDegrees ?? -1, privacy: .public) bounds=\(bounds.width, privacy: .public)x\(bounds.height, privacy: .public) division=\(divisionDescription, privacy: .public) pose=\(String(describing: pose), privacy: .public)"
        )

        model.update(pose: pose, hingeAngleDegrees: angleDegrees)
    }
}
