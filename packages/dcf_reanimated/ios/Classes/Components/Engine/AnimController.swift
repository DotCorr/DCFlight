class AnimationController {
    private weak var view: AnimatedView?
    private var currentAnimation: DirectAnimation?
    
    init(view: AnimatedView) {
        self.view = view
    }
    
    func executeCommand(_ command: [String: Any]) {
        guard let view = view else { return }
        
        let commandType = command["type"] as? String ?? ""
        
        switch commandType {
        case "animate":
            startDirectAnimation(command)
        case "reset":
            view.resetToInitialState()
            currentAnimation = nil
        case "pause":
            currentAnimation?.isPaused = true
        case "resume":
            currentAnimation?.isPaused = false
        case "stop":
            currentAnimation = nil
            break
        default:
            break
        }
    }
    
    private func startDirectAnimation(_ command: [String: Any]) {
        guard let view = view else { return }
        
        // Stop any existing animation
        currentAnimation = nil
        
        // Create new direct animation
        currentAnimation = DirectAnimation(
            view: view,
            command: command,
            startTime: CACurrentMediaTime()
        )
        
        print("🎬 AnimationController: Started direct UI thread animation")
    }
    
    // Returns true if animation is active
    func updateFrame(currentTime: CFTimeInterval) -> Bool {
        guard let animation = currentAnimation else { return false }
        return animation.updateFrame(currentTime: currentTime)
    }
}