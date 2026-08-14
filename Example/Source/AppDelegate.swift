//
//  AppDelegate.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

// この Example アプリの起動入口です。
// アプリ起動時の初期設定と、Split View の表示切り替えを担当します。
@main
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    // MARK: - Properties

    // アプリの画面全体を管理するウィンドウです。
    var window: UIWindow?

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Storyboard で設定された最初の画面を Split View Controller として取得します。
        let splitViewController = window!.rootViewController as! UISplitViewController

        // 右側の詳細画面を包んでいる Navigation Controller を取得します。
        let navigationController = splitViewController.viewControllers.last as! UINavigationController

        // 画面が狭いときにマスター画面を表示するためのボタンを、詳細画面の左上に追加します。
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem

        // Split View の折りたたみ動作をこの AppDelegate で制御できるようにします。
        splitViewController.delegate = self

        // true を返すと、アプリの起動処理が正常に完了したことを iOS に伝えます。
        return true
    }

    // MARK: - UISplitViewControllerDelegate

    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController)
        -> Bool {
        // iPhone など画面が狭い環境では、Split View の右側画面を左側画面へ統合します。
        // 右側の詳細画面に表示するリクエストがまだ無い場合は、空の詳細画面を閉じます。
        if
            let secondaryAsNavController = secondaryViewController as? UINavigationController,
            let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController {
            return topAsDetailController.request == nil
        }

        // 想定した詳細画面ではない場合は、標準の折りたたみ処理に任せます。
        return false
    }
}
