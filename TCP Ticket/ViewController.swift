//
//  ViewController.swift
//  TCP Ticket
//
//  Created by Илья Халяпин on 17.02.2018.
//  Copyright © 2018 Ilia Khaliapin. All rights reserved.
//

import Cocoa
import SwiftSocket

final class ViewController: NSViewController {
    
    // MARK: - Outlet
    
    /// Порт
    @IBOutlet private weak var portTextField: NSTextField! {
        willSet {
            newValue.stringValue = "12345"
        }
    }
    
    /// IP получателя для начала цикла
    @IBOutlet private weak var startClientIpTextField: NSTextField!
    /// Начальное значение
    @IBOutlet private weak var startInitialValueTextField: NSTextField! {
        willSet {
            newValue.isEditable = false
            newValue.stringValue = "\(0)"
        }
    }
    /// Элемент управления начальным значением
    @IBOutlet private weak var startStepper: NSStepper! {
        willSet {
            newValue.integerValue = 0
        }
    }
    
    /// IP сервера
    @IBOutlet private weak var serverIpTextField: NSTextField!
    /// IP клиента
    @IBOutlet private weak var serverClientIpTextField: NSTextField!
    
    /// Кнопка "Запустить сервер"
    @IBOutlet private weak var serverStartButton: NSButton!
    /// Кнопка "Остановить сервер"
    @IBOutlet private weak var serverStopButton: NSButton! {
        willSet {
            newValue.isEnabled = false
        }
    }
    
    @IBOutlet private weak var logTextView: NSTextView! {
        willSet {
            newValue.isEditable = false
        }
    }
    
    
    // MARK: - Приватные свойства
    
    private var queue = DispatchQueue(label: "ru.ilyahal.queue", qos: .utility, attributes: .concurrent)
    
    /// Сервер
    private var server: TCPServer?
    
}


// MARK: - Приватные свойства

private extension ViewController {
    
    /// Порт
    var port: Int32 {
        return self.portTextField.intValue
    }
    
    /// IP получателя для начала цикла
    var startClientIp: String {
        return self.startClientIpTextField.stringValue
    }
    
    /// Начальное значение
    var initialValue: Int {
        return self.startStepper.integerValue
    }
    
    /// IP сервера
    var serverIp: String {
        return self.serverIpTextField.stringValue
    }
    
    /// IP клиента
    var serverClientIp: String {
        return self.serverClientIpTextField.stringValue
    }
    
}


// MARK: - NSViewController

extension ViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.delegate = self
        self.view.window?.makeFirstResponder(nil)
    }
    
}


// MARK: - Action

private extension ViewController {
    
    /// Изменено стартовое значение
    @IBAction func stepperClicked(_ sender: NSStepper) {
        self.startInitialValueTextField.stringValue = "\(self.initialValue)"
    }
    
    /// Нажата кнопка "Начать цикл"
    @IBAction func runLoopClicked(_ sender: NSButton) {
        let port = self.port
        let clientIp = self.startClientIp
        let number = self.initialValue
        
        self.queue.async {
            self.startClient(clientIp: clientIp, port: port, number: number)
        }
    }
    
    /// Нажата кнопка "Запустить сервер"
    @IBAction func serverStartClicked(_ sender: NSButton) {
        let port = self.port
        let serverIp = self.serverIp
        let clientIp = self.serverClientIp
        
        self.queue.async {
            self.startServer(serverIp: serverIp, port: port, clientIp: clientIp)
        }
        
        sender.isEnabled = false
        self.serverStopButton.isEnabled = true
    }
    
    /// Нажата кнопка "Остановить сервер"
    @IBAction func serverStopClicked(_ sender: NSButton) {
        self.server?.close()
        self.server = nil
        
        sender.isEnabled = false
        self.serverStartButton.isEnabled = true
        
        cleanNotification()
    }
    
}


// MARK: - Приватные методы

private extension ViewController {
    
    /// Лог
    func log(message: String) {
        DispatchQueue.main.async {
            self.logTextView.string += message + "\n"
            self.logTextView.scrollToEndOfDocument(self)
        }
    }
    
    /// Отобразить уведомление
    func showNotification() {
        NSSound.beep()
        
        NSApp.requestUserAttention(.criticalRequest)
        NSApplication.shared.dockTile.badgeLabel = "Bip!"
    }
    
    /// Очистить уведомление
    func cleanNotification() {
        NSApplication.shared.dockTile.badgeLabel = nil
    }
    
    /// Запустить клиента
    func startClient(clientIp: String, port: Int32, number: Int) {
        let client = TCPClient(address: clientIp, port: port)
        switch client.connect(timeout: 10) {
        case .success:
            defer { client.close() }
            
            let endLine = "\r\n"
            let string = "\(number)\(endLine)"
            
            guard let result = string.data(using: .ascii) else {
                let message = "Ошибка при подготовке данных для отправки"
                log(message: message)
                
                return
            }
            
            switch client.send(data: result) {
            case .success:
                let message = "Отправлено значение: \(number)"
                log(message: message)
            case .failure(let error):
                print(error)
            }
        case .failure(let error):
            print(error)
        }
    }
    
    /// Запустить сервер
    func startServer(serverIp: String, port: Int32, clientIp: String) {
        self.server?.close()
        
        let server = TCPServer(address: serverIp, port: port)
        self.server = server
        
        switch server.listen() {
        case .success:
            while server.fd != nil {
                guard let client = server.accept() else {
                    let message = "Ошибка при подключении клиента"
                    log(message: message)
                    
                    continue
                }
                
                guard let bytes = client.read(1024 * 10) else {
                    let message = "Ошибка при чтении данных от клиента"
                    log(message: message)
                    
                    continue
                }
                
                defer { client.close() }
                
                let data = Data(bytes)
                guard let string = String(data: data, encoding: .ascii) else {
                    let message = "Данные клиента имеют неверный формат"
                    log(message: message)
                    
                    continue
                }
                
                let endLine = "\r\n"
                guard let number = Int(string.replacingOccurrences(of: endLine, with: "")) else {
                    let message = "Ошибка при парсинге данных клиента"
                    log(message: message)
                    
                    continue
                }
                
                let message = "Получено значение: \(number)"
                log(message: message)
                
                self.showNotification()
                
                let newNumber = number + 1
                self.queue.asyncAfter(deadline: .now() + .milliseconds(500)) {
                    self.startClient(clientIp: clientIp, port: port, number: newNumber)
                }
            }
        case .failure(let error):
            print(error)
        }
    }
    
}


// MARK: - NSWindowDelegate

extension ViewController: NSWindowDelegate {
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApplication.shared.terminate(nil)
        return true
    }
    
}
