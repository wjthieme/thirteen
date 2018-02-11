//
//  GameView.swift
//  13!
//
//  Created by Wilhelm Thieme on 10/16/17.
//  Copyright © 2017 Wilhelm Thieme. All rights reserved.
//

import SpriteKit

class GameView: SKShapeNode {
    
    var nodes: [BallNode] = []
    private var gameOverNode : GameOverNode
    private var score = 0 {
        didSet {
            if let p = parent as? GameScene {
                p.updateScore(score)
            }
        }
    }
    
    private var running = true {
        didSet {
            isUserInteractionEnabled = running
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    init(rect: CGRect, cornerRadius: CGFloat, color : SKColor) {
        
        gameOverNode = GameOverNode(rect: rect, cornerRadius: cornerRadius)
        
        super.init()
        
        path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        let physics = SKPhysicsBody(edgeLoopFrom: path!)
        physics.affectedByGravity = false
        physics.isDynamic = false
        physics.friction = 0
        physicsBody = physics
        fillColor = color
        isUserInteractionEnabled = true
    }
    
    func nodeWidth(factor: CGFloat) -> CGFloat {
        return (self.frame.width + self.frame.height) * getFactor(factor)
    }
    
    func addNode(_ times : Int) {
        for _ in 0...times-1 {
            let size = nodeWidth(factor: 1)
            let node = BallNode(size: size)
            
            let op = Int(arc4random_uniform(101))
        
            if op < 10 {
                node.oper = .multiply
                let value = Int(arc4random_uniform(2))
                if value == 0 {
                    node.value = -1
                } else if value == 1 {
                    node.value = 2
                }
            } else if op >= 10 {
                node.oper = .plus
            
                let value = generateNumber()
            
                node.value = value
            }
            
            if largestCircleDiameterThatFits() / 2 < node.frame.height {
                gameOver()
                return
            }
        
            self.addChild(node)
            score += abs(node.value)
            self.nodes.append(node)
            node.position = CGPoint(x: frame.width*0.5, y: frame.height*0.5)
            
            if largestCircleDiameterThatFits() / 3 < nodeWidth(factor: 1) {
                startBlinking()
            } else {
                stopBlinking()
            }
        }
    }
    
    func generateNumber() -> Int {
        var random = 0
        for _ in 0...9 {
            random += Int(arc4random_uniform(3)) - 1
        }
        
        if random == 0 || random == 13 {
            random = generateNumber()
        }
        return random
    }
    
    func clearBoard() {
        for node in nodes {
            node.removeFromParent()
        }
        nodes = []
    }
    
    func contains(_ rect: CGRect) -> Bool {
        let points = getPoints(from: rect)
        if self.contains(points.0) && self.contains(points.1) && self.contains(points.2) && self.contains(points.3) {
            return true
        }
        return false
    }
    
    func getPoints(from: CGRect) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let minX = from.minX
        let minY = from.minY
        let maxX = from.maxX
        let maxY = from.maxY
        
        let one = CGPoint(x: minX, y: minY)
        let two = CGPoint(x: minX, y: maxY)
        let three = CGPoint(x: maxX, y: minY)
        let four = CGPoint(x: maxX, y: maxY)
        
        return (one, two, three, four)
    }
    
    var movableNode: BallNode?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            
            for node in nodes {
                if node.contains(location) {
                    movableNode = node
                    node.isPickedUp = true
                    return
                }
            }
        }
    }
    
    var hapticNode: BallNode? {
        didSet {
            if hapticNode != oldValue, hapticNode != nil {
                createHaptic(type: .snap)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
        
            if let movable = movableNode {
                movable.zRotation = 0
                
                let rect = CGRect(x: location.x-movable.frame.width*0.5, y: location.y-movable.frame.height*0.5, width: movable.frame.width, height: movable.frame.height)
                if contains(rect) {
                    movable.position = location
                }
                
                for node in nodes {
                    node.isSelected = node.contains(location)
                    
                    if node.contains(location) && node != movable {
                        hapticNode = node
                        movable.position = node.position
                        return
                    }
                }
                hapticNode = nil
            }
        }
    }
    
    override  func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            if let movable = movableNode {
                for node in nodes {
                    if node.contains(location) && !node.isEqual(to: movable) {
                        
                        let value1 = movable.value
                        let op1 = movable.oper
                        let value2 = node.value
                        let op2 = node.oper
                        
                        var newValue = 0
                        var newOper = BallNode.operators.plus
                        
                        if op1 == .multiply || op2 == .multiply {
                            newValue = value1 * value2
                        } else {
                            newValue = value1 + value2
                        }
                        
                        if op1 == .multiply && op2 == .multiply {
                            newOper = .multiply
                        }
                        
                        let newAdded = node.timesAdded + movable.timesAdded
                        let newSize = nodeWidth(factor: newAdded)
                        
                        movable.removeFromParent()
                        if let at = nodes.index(of: movable) {
                            nodes.remove(at: at)
                        }
                        
                        node.oper = newOper
                        node.value = newValue
                        node.timesAdded = newAdded
                        node.grow(to: newSize)
                        
    
                        
                        if node.value == 13 && node.oper == .plus {
                            pop(node)
                            addNode(2)
                        } else {
                            addNode(1)
                        }
                        
                        movableNode = nil
                        node.isSelected = false
                        return
                        
                    }
                }
                movable.isPickedUp = false
                movableNode = nil
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let movable = movableNode {
            movable.isPickedUp = false
            movableNode = nil
        }
    }
    
    func nodeAtLocation(_ at: CGPoint, _ thisNode: BallNode) -> Bool {
        for node in nodes {
            if node.contains(at) && !node.isEqual(to: thisNode) {
                return true
            }
        }
        return false
    }
    
    func pop(_ node: BallNode) {
        let num = Int(arc4random_uniform(5))
        var playSound = SKAction.playSoundFileNamed("Pop\(num).wav", waitForCompletion: false)
        
        if UserDefaults.standard.bool(forKey: Keys.muted) {
            playSound = SKAction.wait(forDuration: 0)
        }
        
        node.run(SKAction.sequence([SKAction.wait(forDuration: 0.3), playSound]), completion:  {
            node.removeFromParent()
            self.score += 13
        })
        
        let ID = nodes.index(of: node)
        if let at = ID {
            nodes.remove(at: at)
        }
    }
    
    func getFactor(_ size : CGFloat) -> CGFloat {
        if score < 1000 {
            return (size * 0.02 + 0.08) * (CGFloat(score)/5000 + 1)
        }
        return (size * 0.02 + 0.08) * 1.2
    }
    
    func gameOver() {
        if let vc = self.scene?.view?.window?.rootViewController as? GameViewController {
            self.addChild(gameOverNode)
            running = false
            vc.updateGC(score)
            stopBlinking()
            createHaptic(type: .gameOver)
        }

    }
    
    func restart() {
        if running, let vc = self.scene?.view?.window?.rootViewController as? GameViewController {
            vc.updateGC(score)
        }
        
        clearBoard()
        score = 0
        addNode(10)
        gameOverNode.removeFromParent()
        running = true
        
        if let pos = nodes.last?.position {
            nodes.last?.position = CGPoint(x: pos.x+1, y: pos.y+1)
        }
    }
    
    var timer: Timer?
    
    func startBlinking() {
        guard timer == nil else {
            return
        }
        let color1 = SKColor(red: 253/255, green: 245/255, blue: 230/255, alpha: 1)
        let color2 = SKColor(red: 203/255, green: 195/255, blue: 180/255, alpha: 1)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (timer) in
            self.run(SKAction.sequence([SKAction.customAction(withDuration: 0.2, actionBlock: { (node, _) in
                let nod = node as? SKShapeNode
                nod?.fillColor = color2
            }),SKAction.customAction(withDuration: 0.2, actionBlock: { (node, _) in
                let nod = node as? SKShapeNode
                nod?.fillColor = color1
            })]))
        })
    }
    
    func stopBlinking() {
        guard timer != nil else {
            return
        }
        timer?.invalidate()
        timer = nil
    }
    
    func largestCircleDiameterThatFits() -> CGFloat {
        
        var ballArea: CGFloat = 0
        
        for ball in self.nodes {
            let area = pow(ball.size,2)
            ballArea += area
        }
        
        let boardArea = frame.width*frame.height
        let leftOver = (boardArea-ballArea).squareRoot()
        
        return leftOver
    }
    
    let impact = UIImpactFeedbackGenerator()
    let notification = UINotificationFeedbackGenerator()
    
    enum hapticType {
        case gameOver, blinking, snap, thirteen
    }
    
    func createHaptic(type: hapticType) {
        guard !UserDefaults.standard.bool(forKey: Keys.hapticDisabled) else {
            return
        }
        
        switch type {
        case .gameOver:
            notification.notificationOccurred(.error)
        case .blinking:
            notification.notificationOccurred(.warning)
        case .thirteen:
            notification.notificationOccurred(.success)
        case .snap:
            impact.impactOccurred()
        }
        
    }
    
}
