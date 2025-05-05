import UIKit

class SplashAnimationViewController: UIViewController {
    // Properties for animation
    private var letterLayers: [CATextLayer] = []
    private let letters = ["L", "u", "s", "h", "y"]
    private let animationDuration: TimeInterval = 1.8
    
    // Completion handler to call when animation finishes
    var onAnimationCompleted: (() -> Void)?
    
    // Fallback timer in case animation fails
    private var fallbackTimer: Timer?
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Important: Make view background clear so SwiftUI background shows through
        view.backgroundColor = .clear
        
        setupView()
        
        // Safety fallback in case animation fails
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            if let completion = self?.onAnimationCompleted {
                completion()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set up edge-to-edge UI
        setupEdgeToEdgeAppearance()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimation()
    }
    
    deinit {
        fallbackTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupEdgeToEdgeAppearance() {
        // Extend background to the edges of the screen
        let lushyCream = UIColor(named: "LushyCream") ?? .white
        
        // Configure the view to extend under the status bar and bottom indicator
        view.backgroundColor = lushyCream
        
        // Configure status bar appearance
        setNeedsStatusBarAppearanceUpdate()
        
        // Apply same color to navigation bar if it exists
        navigationController?.navigationBar.backgroundColor = lushyCream
        navigationController?.navigationBar.barTintColor = lushyCream
        
        // Make background extend edge-to-edge
        edgesForExtendedLayout = .all
        
        // For iOS 13 and above, handle the appearance correctly
        if #available(iOS 13.0, *) {
            // Don't create an unused variable - just use it directly if needed
            if UIApplication.shared.connectedScenes.first is UIWindowScene {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = lushyCream
                navigationController?.navigationBar.standardAppearance = appearance
                navigationController?.navigationBar.scrollEdgeAppearance = appearance
            }
        }
    }
    
    // Make sure status bar style matches our design
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent // Use dark content for light background
    }
    
    private func setupView() {
        createLetterLayers()
    }
    
    private func createLetterLayers() {
        // Use a bolder, bubbly font
        let fontName = "ChalkboardSE-Bold"
        let fontSize: CGFloat = 64
        
        let font = UIFont(name: fontName, size: fontSize) ?? UIFont.boldSystemFont(ofSize: fontSize)
        
        // Create a string to measure total width
        let fullString = "Lushy"
        let fullWidth = fullString.size(withAttributes: [.font: font]).width
        let letterHeight = fullString.size(withAttributes: [.font: font]).height
        
        // Position the word in the exact center of the screen
        let startX = (view.bounds.width - fullWidth) / 2
        
        // Simple, direct approach to center vertically
        // Use exact screen middle with a larger offset to move it up
        let visualCenterY = view.bounds.height / 2 - 40
        
        // Get brand color
        let brandColor = UIColor(named: "LushyPink") ?? .systemPink
        
        // Create text for each letter
        var currentX = startX
        for letter in letters {
            let letterWidth = letter.size(withAttributes: [.font: font]).width
            
            let textLayer = CATextLayer()
            textLayer.string = letter
            textLayer.font = CGFont(font.fontName as CFString)
            textLayer.fontSize = font.pointSize
            textLayer.foregroundColor = brandColor.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale
            
            // Size and position - ensure perfect centering
            textLayer.frame = CGRect(
                x: currentX,
                y: visualCenterY - letterHeight/2,
                width: letterWidth,
                height: letterHeight
            )
            
            // Start with zero opacity
            textLayer.opacity = 0
            
            view.layer.addSublayer(textLayer)
            letterLayers.append(textLayer)
            
            currentX += letterWidth
        }
    }
    
    // MARK: - Animation
    
    private func startAnimation() {
        animateLetterEntrance()
    }
    
    private func animateLetterEntrance() {
        // Animate letters appearing with a squishy effect
        for (index, layer) in letterLayers.enumerated() {
            let delay = 0.06 * Double(index)
            
            // Squishy appearance - start wide and short, then normalize
            let squishAnimation = CAKeyframeAnimation(keyPath: "transform")
            
            // Create transforms with different scale values for width/height to create squish effect
            let initialTransform = CATransform3DMakeScale(1.3, 0.7, 1.0)
            let overcompensateTransform = CATransform3DMakeScale(0.8, 1.2, 1.0)
            let finalTransform = CATransform3DIdentity
            
            squishAnimation.values = [
                initialTransform,
                overcompensateTransform,
                finalTransform
            ]
            squishAnimation.keyTimes = [0.0, 0.6, 1.0]
            squishAnimation.duration = 0.5
            squishAnimation.beginTime = CACurrentMediaTime() + delay
            squishAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            squishAnimation.fillMode = .forwards
            squishAnimation.isRemovedOnCompletion = false
            
            // Fade in animation
            let fadeAnimation = CABasicAnimation(keyPath: "opacity")
            fadeAnimation.fromValue = 0.0
            fadeAnimation.toValue = 1.0
            fadeAnimation.duration = 0.3
            fadeAnimation.beginTime = CACurrentMediaTime() + delay
            fadeAnimation.fillMode = .forwards
            fadeAnimation.isRemovedOnCompletion = false
            
            layer.add(squishAnimation, forKey: "squishIn")
            layer.add(fadeAnimation, forKey: "fadeIn")
            layer.opacity = 1
        }
        
        // After letters appear, do a single elegant wave
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.animateElegantWave()
        }
    }
    
    private func animateElegantWave() {
        // Create a wave that has a squishy quality
        for (index, layer) in letterLayers.enumerated() {
            let delay = 0.05 * Double(index)
            
            // Vertical wave motion
            let waveAnimation = CAKeyframeAnimation(keyPath: "position.y")
            let originalY = layer.position.y
            waveAnimation.values = [originalY, originalY - 12, originalY + 6, originalY]
            waveAnimation.keyTimes = [0, 0.4, 0.7, 1.0]
            waveAnimation.duration = 0.5
            waveAnimation.beginTime = CACurrentMediaTime() + delay
            waveAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            // Add a small squish during the wave
            let squishAnimation = CAKeyframeAnimation(keyPath: "transform")
            
            // Create transforms that squish in opposite direction of movement
            let normalTransform = CATransform3DIdentity
            let stretchUp = CATransform3DMakeScale(0.9, 1.1, 1.0)
            let squishDown = CATransform3DMakeScale(1.1, 0.9, 1.0)
            
            squishAnimation.values = [
                normalTransform,
                stretchUp,
                squishDown,
                normalTransform
            ]
            squishAnimation.keyTimes = [0, 0.4, 0.7, 1.0]
            squishAnimation.duration = 0.5
            squishAnimation.beginTime = CACurrentMediaTime() + delay
            squishAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            // Apply both animations for a squishy wave effect
            layer.add(waveAnimation, forKey: "waveAnimation")
            layer.add(squishAnimation, forKey: "squishAnimation")
        }
        
        // After wave, perform final unified bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.animateFinalBounce()
        }
    }
    
    private func animateFinalBounce() {
        // Create a quick, unified bounce with squishy quality
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        // Create bounce transforms with squishy quality
        let normalTransform = CATransform3DIdentity
        let squishWide = CATransform3DMakeScale(1.1, 0.92, 1.0)
        let squishTall = CATransform3DMakeScale(0.95, 1.05, 1.0)
        let almostNormal = CATransform3DMakeScale(1.02, 0.98, 1.0)
        
        scaleAnimation.values = [
            normalTransform,
            squishWide,
            squishTall,
            almostNormal,
            normalTransform
        ]
        scaleAnimation.keyTimes = [0.0, 0.25, 0.5, 0.75, 1.0]
        scaleAnimation.duration = 0.6
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Apply animation to each letter for unified effect
        for layer in letterLayers {
            layer.add(scaleAnimation, forKey: "finalBounce")
        }
        
        // Create a flag to ensure completion is only called once
        var hasCalledCompletion = false
        
        // Animation done, clean up and call completion handler
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self = self, !hasCalledCompletion else { return }
            
            hasCalledCompletion = true
            self.fallbackTimer?.invalidate()
            self.fallbackTimer = nil
            
            // Call completion on main thread to be safe
            DispatchQueue.main.async {
                self.onAnimationCompleted?()
            }
        }
    }
}