//
//  MediaGridContainerView.swift
//  MediaGridContainerView
//
//  Created by Cirno MainasuK on 2021-8-23.
//  Copyright © 2021 Twidere. All rights reserved.
//

import os.log
import UIKit
import func AVFoundation.AVMakeRect

public protocol MediaGridContainerViewDelegate: AnyObject {
    func mediaGridContainerView(_ container: MediaGridContainerView, didTapMediaView mediaView: MediaView, at index: Int)
    func mediaGridContainerView(_ container: MediaGridContainerView, mediaSensitiveButtonDidPressed button: UIButton)
}

public final class MediaGridContainerView: UIView {
    
    static let sensitiveToggleButtonSize = CGSize(width: 34, height: 34)
    public static let maxCount = 10
    
    let logger = Logger(subsystem: "MediaGridContainerView", category: "UI")
    
    public weak var delegate: MediaGridContainerViewDelegate?
    public private(set) lazy var viewModel: ViewModel = {
        let viewModel = ViewModel()
        viewModel.bind(view: self)
        return viewModel
    }()
    
    // lazy var is required here to setup gesture recognizer target-action
    // Swift not doesn't emit compiler error if without `lazy` here
    private(set) lazy var _mediaViews: [MediaView] = {
        var mediaViews: [MediaView] = []
        for i in 0..<MediaGridContainerView.maxCount {
            // init media view
            let mediaView = MediaView()
            mediaView.tag = i
            mediaViews.append(mediaView)
            
            // add gesture recognizer
            let tapGesture = UITapGestureRecognizer.singleTapGestureRecognizer
            tapGesture.addTarget(self, action: #selector(MediaGridContainerView.mediaViewTapGestureRecognizerHandler(_:)))
            mediaView.container.addGestureRecognizer(tapGesture)
            mediaView.container.isUserInteractionEnabled = true
        }
        return mediaViews
    }()
    
    let contentWarningOverlay = ContentWarningOverlayView()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        _init()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        _init()
    }
    
    public override var accessibilityElements: [Any]? {
        get {
            mediaViews
        }
        set { }
    }

}

extension MediaGridContainerView {
    private func _init() {
        contentWarningOverlay.isUserInteractionEnabled = false
        contentWarningOverlay.isHidden = true
    }
}

extension MediaGridContainerView {
    @objc private func mediaViewTapGestureRecognizerHandler(_ sender: UITapGestureRecognizer) {
        guard let index = _mediaViews.firstIndex(where: { $0.container === sender.view }) else { return }
        logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): \(index)")
        let mediaView = _mediaViews[index]
        delegate?.mediaGridContainerView(self, didTapMediaView: mediaView, at: index)
    }

    @objc private func sensitiveToggleButtonDidPressed(_ sender: UIButton) {
        logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public)")
        delegate?.mediaGridContainerView(self, mediaSensitiveButtonDidPressed: sender)
    }
}

extension MediaGridContainerView {

    public func dequeueMediaView(adaptiveLayout layout: AdaptiveLayout) -> MediaView {
        prepareForReuse()
        
        let mediaView = _mediaViews[0]
        layout.layout(in: self, mediaView: mediaView)
        
        layoutContentWarningOverlay()
        bringSubviewToFront(contentWarningOverlay)
        
        return mediaView
    }
    
    public func dequeueMediaView(gridLayout layout: GridLayout) -> [MediaView] {
        prepareForReuse()
        
        let mediaViews = Array(_mediaViews[0..<layout.count])
        layout.layout(in: self, mediaViews: mediaViews)
        
        layoutContentWarningOverlay()
        bringSubviewToFront(contentWarningOverlay)
        
        return mediaViews
    }
    
    public func prepareForReuse() {
        _mediaViews.forEach { view in
            view.removeFromSuperview()
            view.removeConstraints(view.constraints)
            view.prepareForReuse()
        }
        
        subviews.forEach { view in
            view.removeFromSuperview()
        }
        
        removeConstraints(constraints)
    }

}

extension MediaGridContainerView {
    private func layoutContentWarningOverlay() {
        contentWarningOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentWarningOverlay)
        contentWarningOverlay.pinToParent()
    }
}

extension MediaGridContainerView {
    
    public var mediaViews: [MediaView] {
        _mediaViews.filter { $0.superview != nil }
    }
    
    public func setAlpha(_ alpha: CGFloat) {
        _mediaViews.forEach { $0.alpha = alpha }
    }
    
    public func setAlpha(_ alpha: CGFloat, index: Int) {
        if index < _mediaViews.count {
            _mediaViews[index].alpha = alpha
        }
    }
    
}

extension MediaGridContainerView {
    public struct AdaptiveLayout {
        let aspectRatio: CGSize
        let maxSize: CGSize
        
        func layout(in view: UIView, mediaView: MediaView) {
            let imageViewSize = AVMakeRect(aspectRatio: aspectRatio, insideRect: CGRect(origin: .zero, size: maxSize)).size
            mediaView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(mediaView)
            NSLayoutConstraint.activate([
                mediaView.topAnchor.constraint(equalTo: view.topAnchor),
                mediaView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                mediaView.trailingAnchor.constraint(equalTo: view.trailingAnchor).priority(.defaultLow),
                mediaView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                mediaView.widthAnchor.constraint(equalToConstant: imageViewSize.width).priority(.required - 1),
                mediaView.heightAnchor.constraint(equalToConstant: imageViewSize.height).priority(.required - 1),
            ])
        }
    }
    
    public struct GridLayout {
        static let spacing: CGFloat = 1
        
        let count: Int
        let maxSize: CGSize
		let layout: MediaLayoutResult
        
		init(count: Int, maxSize: CGSize, layout: MediaLayoutResult) {
            self.count = min(count, 10)
            self.maxSize = maxSize
			self.layout = layout
        }
        
        private func createStackView(axis: NSLayoutConstraint.Axis) -> UIStackView {
            let stackView = UIStackView()
            stackView.axis = axis
            stackView.semanticContentAttribute = .forceLeftToRight
            stackView.spacing = GridLayout.spacing
            stackView.distribution = .fillEqually
            return stackView
        }
        
        public func layout(in view: UIView, mediaViews: [MediaView]) {
            let count = mediaViews.count
			
			if count<2 || count>maxCount {
				assertionFailure("unexpected attachment count \(count)")
				return
			}
			
			let layoutView = GridLayoutView()
			layoutView.translatesAutoresizingMaskIntoConstraints = false
			view.addSubview(layoutView)
			layoutView.pinToParent()
			for mediaView in mediaViews {
				layoutView.addSubview(mediaView)
			}
			layoutView.prepare(layout: layout, maxSize: maxSize)
			
            /*switch count {
            case 1:
                assertionFailure("should use Adaptive Layout")
                containerVerticalStackView.addArrangedSubview(mediaViews[0])
            case 2:
                let horizontalStackView = createStackView(axis: .horizontal)
                containerVerticalStackView.addArrangedSubview(horizontalStackView)
                horizontalStackView.addArrangedSubview(mediaViews[0])
                horizontalStackView.addArrangedSubview(mediaViews[1])
            case 3:
                let horizontalStackView = createStackView(axis: .horizontal)
                containerVerticalStackView.addArrangedSubview(horizontalStackView)
                horizontalStackView.addArrangedSubview(mediaViews[0])
                
                let verticalStackView = createStackView(axis: .vertical)
                horizontalStackView.addArrangedSubview(verticalStackView)
                verticalStackView.addArrangedSubview(mediaViews[1])
                verticalStackView.addArrangedSubview(mediaViews[2])
            case 4:
                let topHorizontalStackView = createStackView(axis: .horizontal)
                containerVerticalStackView.addArrangedSubview(topHorizontalStackView)
                topHorizontalStackView.addArrangedSubview(mediaViews[0])
                topHorizontalStackView.addArrangedSubview(mediaViews[1])
                
                let bottomHorizontalStackView = createStackView(axis: .horizontal)
                containerVerticalStackView.addArrangedSubview(bottomHorizontalStackView)
                bottomHorizontalStackView.addArrangedSubview(mediaViews[2])
                bottomHorizontalStackView.addArrangedSubview(mediaViews[3])
            case 5...9:
                let topHorizontalStackView = createStackView(axis: .horizontal)
                containerVerticalStackView.addArrangedSubview(topHorizontalStackView)
                topHorizontalStackView.addArrangedSubview(mediaViews[0])
                topHorizontalStackView.addArrangedSubview(mediaViews[1])
                topHorizontalStackView.addArrangedSubview(mediaViews[2])
                
                func mediaViewOrPlaceholderView(at index: Int) -> UIView {
                    return index < mediaViews.count ? mediaViews[index] : UIView()
                }
                let middleHorizontalStackView = createStackView(axis: .horizontal)
                containerVerticalStackView.addArrangedSubview(middleHorizontalStackView)
                middleHorizontalStackView.addArrangedSubview(mediaViews[3])
                middleHorizontalStackView.addArrangedSubview(mediaViews[4])
                middleHorizontalStackView.addArrangedSubview(mediaViewOrPlaceholderView(at: 5))
                
                if count > 6 {
                    let bottomHorizontalStackView = createStackView(axis: .horizontal)
                    containerVerticalStackView.addArrangedSubview(bottomHorizontalStackView)
                    bottomHorizontalStackView.addArrangedSubview(mediaViewOrPlaceholderView(at: 6))
                    bottomHorizontalStackView.addArrangedSubview(mediaViewOrPlaceholderView(at: 7))
                    bottomHorizontalStackView.addArrangedSubview(mediaViewOrPlaceholderView(at: 8))
                }
            default:
                assertionFailure()
                return
            }*/
            
            let containerWidth = maxSize.width
			let containerHeight = CGFloat(layoutView.getMeasuredHeight())
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalToConstant: containerWidth).priority(.required - 1),
                view.heightAnchor.constraint(equalToConstant: containerHeight).priority(.required - 1),
            ])
        }
    }
}

class GridLayoutView : UIView {
	private var layout: MediaLayoutResult?
	private var measuredHeight = 0
	
	private static let maxWidth = 400
	private static let gap = 2
	
	public func prepare(layout: MediaLayoutResult, maxSize: CGSize) {
		self.layout = layout
		let width: Float = min(Float(maxSize.width), Float(GridLayoutView.maxWidth))
		let height: Float = (width*Float(layout.height)/MediaLayoutHelper.maxWidth)
		measuredHeight = Int(height.rounded())
	}
	
	public func getMeasuredHeight() -> Int {
		return measuredHeight
	}
	
	override func layoutSubviews() {
		guard let layout = layout else { return }
		var width: Int = min(GridLayoutView.maxWidth, Int(frame.width))
		let height: Int = Int(frame.height)
		if layout.width<Int(MediaLayoutHelper.maxWidth) {
			width = Int((Float(width)*(Float(layout.width)/MediaLayoutHelper.maxWidth)).rounded())
		}
		
		var columnStarts: [Int] = []
		var columnEnds: [Int] = []
		var rowStarts: [Int] = []
		var rowEnds: [Int] = []
		var offset: Int = 0
		
		for colSize in layout.columnSizes {
			columnStarts.append(offset)
			offset += Int((Float(colSize)/Float(layout.width)*Float(width)).rounded())
			columnEnds.append(offset)
			offset += GridLayoutView.gap
		}
		columnEnds.append(width)
		offset = 0
		for rowSize in layout.rowSizes {
			rowStarts.append(offset)
			offset += Int((Float(rowSize)/Float(layout.height)*Float(height)).rounded())
			rowEnds.append(offset)
			offset += GridLayoutView.gap
		}
		rowEnds.append(height)
		
		var xOffset: Int = 0
		if Int(frame.width)>width {
			xOffset = Int((Float(frame.width)/2.0-Float(width)/2.0).rounded())
		}
		
		for (i, view) in subviews.enumerated() {
			if i>=layout.tiles.count {
				break // TODO make sure any additional subviews are only added at the end
			}
			let tile = layout.tiles[i]
			let colSpan = max(1, tile.colSpan) - 1
			let rowSpan = max(1, tile.rowSpan) - 1
			let x = columnStarts[tile.startCol]
			let y = rowStarts[tile.startRow]
			view.frame = CGRect(x: x+xOffset, y: y, width: columnEnds[tile.startCol+colSpan]-x, height: rowEnds[tile.startRow+rowSpan]-y)
		}
	}
}

