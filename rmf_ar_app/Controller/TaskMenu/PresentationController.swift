    //
    //  PresentationController.swift
    //  rmf_ar_app
    //
    //  Created by Matthew Booker on 6/7/21.
    //
    
    import UIKit
    
    class PresentationController: UIPresentationController {
        
        let dimmedView: UIView!
        var tapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
        
        override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
            dimmedView = UIView()
            dimmedView.backgroundColor = .black
            
            super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
            
            tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissController))
            dimmedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            self.dimmedView.isUserInteractionEnabled = true
            self.dimmedView.addGestureRecognizer(tapGestureRecognizer)
        }
        
        override var frameOfPresentedViewInContainerView: CGRect {
            CGRect(origin: CGPoint(x: 0, y: self.containerView!.frame.height * 0.4),
                   size: CGSize(width: self.containerView!.frame.width, height: self.containerView!.frame.height *
                                    0.6))
        }
        
        override func presentationTransitionWillBegin() {
            self.dimmedView.alpha = 0
            self.containerView?.addSubview(dimmedView)
            self.presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
                self.dimmedView.alpha = 0.7
            }, completion: nil)
        }
        
        override func dismissalTransitionWillBegin() {
            self.presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
                self.dimmedView.alpha = 0
            }, completion: { _ in
                self.dimmedView.removeFromSuperview()
            })
        }
        
        override func containerViewWillLayoutSubviews() {
            super.containerViewWillLayoutSubviews()
            presentedView!.roundCorners([.topLeft, .topRight], radius: 15)
        }
        
        override func containerViewDidLayoutSubviews() {
            super.containerViewDidLayoutSubviews()
            presentedView?.frame = frameOfPresentedViewInContainerView
            dimmedView.frame = containerView!.bounds
        }
        
        @objc func dismissController(){
            self.presentedViewController.dismiss(animated: true, completion: nil)
        }
    }
    
    extension UIView {
        func roundCorners(_ corners: UIRectCorner, radius: CGFloat) {
            let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners,
                                    cornerRadii: CGSize(width: radius, height: radius))
            let mask = CAShapeLayer()
            mask.path = path.cgPath
            layer.mask = mask
        }
    }
