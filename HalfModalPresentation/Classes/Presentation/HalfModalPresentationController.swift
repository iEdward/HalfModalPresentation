import UIKit

enum ModalScaleState {
    case adjustedOnce
    case normal
}

class HalfModalPresentationController : UIPresentationController {
    var isMaximized: Bool = false
    
    var _dimmingView: UIView?
    var panGestureRecognizer: UIPanGestureRecognizer
    var direction: CGFloat = 0
    var state: ModalScaleState = .normal
    var dimmingView: UIView {
        if let dimmedView = _dimmingView {
            return dimmedView
        }
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: containerView!.bounds.width, height: containerView!.bounds.height))
        view.backgroundColor = .black
        _dimmingView = view
        
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        view.addGestureRecognizer(recognizer)
        
        return view
    }
    let rect: CGRect
    
    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        self.panGestureRecognizer = UIPanGestureRecognizer()
        self.rect = presentingViewController?.view.bounds ?? .zero
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        panGestureRecognizer.addTarget(self, action: #selector(onPan(pan:)))
        presentedViewController.view.addGestureRecognizer(panGestureRecognizer)
        
        corners()
    }
    
    @objc func onPan(pan: UIPanGestureRecognizer) -> Void {
        let endPoint = pan.translation(in: pan.view?.superview)
        
        switch pan.state {
        case .began:
            break
        case .changed:
            let velocity = pan.velocity(in: pan.view?.superview)
            let rect: CGRect
            switch state {
            case .normal:
                rect =
                    CGRect(origin: CGPoint(x: 0,
                                           y: endPoint.y + containerView!.frame.height / 4),
                           size: CGSize(width: self.containerView!.frame.width,
                                        height: self.containerView!.frame.height - (endPoint.y + containerView!.frame.height / 4)))
            case .adjustedOnce:
                rect =
                    CGRect(origin: CGPoint(x: 0,
                                           y: endPoint.y + 40),
                           size: CGSize(width: self.containerView!.frame.width,
                                        height: self.containerView!.frame.height - (endPoint.y + 40)))
            }
            direction = velocity.y
            
            if rect.origin.y <= 0 {
                changeScale(to: .adjustedOnce)
            } else if rect.origin.y > containerView!.frame.height / 2 {
                presentedViewController.dismiss(animated: true, completion: nil)
            }else {
                presentedView!.frame = rect
            }
            break
        case .ended:
            if direction < 0 {
                changeScale(to: .adjustedOnce)
            } else {
                if state == .adjustedOnce {
                    changeScale(to: .normal)
                } else {
                    presentedViewController.dismiss(animated: true, completion: nil)
                }
            }
            break
        default:
            break
        }
    }
    
    func changeScale(to state: ModalScaleState) {
        if let presentedView = presentedView, let containerView = self.containerView {
            UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.5, options: .curveEaseIn, animations: { () -> Void in
                //                presentedView.frame = containerView.frame
                let containerFrame = containerView.frame
                let topFrame = CGRect(origin: CGPoint(x: 0, y: containerFrame.origin.y + 40),
                                      size: CGSize(width: containerFrame.width, height: containerFrame.height - 40))
                let halfFrame = CGRect(origin: CGPoint(x: 0, y: containerFrame.height / 4),
                                       size: CGSize(width: containerFrame.width, height: containerFrame.height * 3 / 4))
                let frame = state == .adjustedOnce ? topFrame : halfFrame
                
                presentedView.frame = frame
                presentedView.layoutIfNeeded()
                
                if let navController = self.presentedViewController as? UINavigationController {
                    self.isMaximized = true
                    
                    navController.setNeedsStatusBarAppearanceUpdate()
                    
                    // Force the navigation bar to update its size
                    navController.isNavigationBarHidden = true
                    navController.isNavigationBarHidden = false
                }
            }, completion: { (isFinished) in
                self.state = state
            })
        }
    }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        return CGRect(x: 0, y: containerView!.bounds.height / 4, width: containerView!.bounds.width, height: containerView!.bounds.height * 3 / 4)
    }
    
    override func presentationTransitionWillBegin() {
        let dimmedView = dimmingView
        
        if let containerView = self.containerView, let coordinator = presentingViewController.transitionCoordinator {
            
            dimmedView.alpha = 0
            containerView.addSubview(dimmedView)
            dimmedView.addSubview(presentedViewController.view)
            
            coordinator.animate(alongsideTransition: { (context) -> Void in
                dimmedView.alpha = 0.6
            }, completion: nil)
        }
    }
    
    override func dismissalTransitionWillBegin() {
        if let coordinator = presentingViewController.transitionCoordinator {
            
            coordinator.animate(alongsideTransition: { (context) -> Void in
                self.dimmingView.alpha = 0
            }, completion: { (completed) -> Void in
                print("done dismiss animation")
            })
            
        }
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        print("dismissal did end: \(completed)")
        
        if completed {
            dimmingView.removeFromSuperview()
            _dimmingView = nil
            
            isMaximized = false
        }
    }
    
    fileprivate func corners() {
        let path = UIBezierPath(roundedRect:presentedViewController.view.bounds,
                                byRoundingCorners:[.topRight, .topLeft],
                                cornerRadii: CGSize(width: 10, height:  10))
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        presentedViewController.view.layer.mask = maskLayer
    }
    
    @objc dynamic func handleTap(recognizer: UITapGestureRecognizer) {
        presentingViewController.dismiss(animated: true)
    }
}

public
protocol HalfModalPresentable { }

extension HalfModalPresentable where Self: UIViewController {
    func maximizeToFullScreen() -> Void {
        if let presetation = navigationController?.presentationController as? HalfModalPresentationController {
            presetation.changeScale(to: .adjustedOnce)
        }
    }
}

extension HalfModalPresentable where Self: UINavigationController {
    func isHalfModalMaximized() -> Bool {
        if let presentationController = presentationController as? HalfModalPresentationController {
            return presentationController.isMaximized
        }
        
        return false
    }
}
