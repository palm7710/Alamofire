//
//  DetailViewController.swift
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

import Alamofire
import UIKit

// 選択された Alamofire のリクエストを実行し、
// レスポンスヘッダー・本文・通信時間をテーブルに表示する画面です。
class DetailViewController: UITableViewController {
    // テーブルを「ヘッダー表示」と「本文表示」の 2 セクションに分けます。
    enum Sections: Int {
        case headers, body
    }

    // Master 画面で選ばれた Alamofire のリクエストです。
    // 新しいリクエストが設定されたら、古い通信を止めて表示状態をリセットします。
    var request: Request? {
        didSet {
            // 前回のリクエストが残っている場合は、結果が混ざらないようにキャンセルします。
            oldValue?.cancel()

            // ナビゲーションバーのタイトルに、現在のリクエスト内容を表示します。
            title = request.map(String.init(describing:))

            // URLRequest が作られたタイミングで、より詳しいリクエスト説明にタイトルを更新します。
            request?.onURLRequestCreation { [weak self] _ in
                self?.title = self?.request.map(String.init(describing:))
            }

            // 画面に出ている前回の結果を消して、次の通信結果を待つ状態にします。
            refreshControl?.endRefreshing()
            headers.removeAll()
            body = nil
            elapsedTime = nil
        }
    }

    var headers: [String: String] = [:]
    var body: String?
    var elapsedTime: TimeInterval?
    var segueIdentifier: String?

    // 通信時間を画面に表示しやすい数値形式に整えるためのフォーマッターです。
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    // MARK: View Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()

        // 画面を下に引っ張って更新したときに refresh() を呼びます。
        refreshControl?.addTarget(self, action: #selector(DetailViewController.refresh), for: .valueChanged)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 詳細画面が表示されたら、現在選択されているリクエストを実行します。
        refresh()
    }

    // MARK: IBActions

    @IBAction func refresh() {
        // 表示対象のリクエストがまだ無い場合は何もしません。
        guard let request else {
            return
        }

        // 通信中であることを UI に表示します。
        refreshControl?.isHidden = false
        refreshControl?.beginRefreshing()

        // 通信にかかった時間を測るため、開始時刻を記録します。
        let start = CACurrentMediaTime()

        // DataRequest と DownloadRequest の完了処理を共通化します。
        let requestComplete: (HTTPURLResponse?, Result<String, AFError>) -> Void = { response, result in
            // 終了時刻との差分から通信時間を計算します。
            let end = CACurrentMediaTime()
            self.elapsedTime = end - start

            // HTTP レスポンスヘッダーを文字列の辞書に変換して表示用に保存します。
            if let response {
                for (field, value) in response.allHeaderFields {
                    self.headers["\(field)"] = "\(value)"
                }
            }

            // 選ばれたサンプルの種類に応じて、レスポンス本文の取り出し方を切り替えます。
            if let segueIdentifier = self.segueIdentifier {
                switch segueIdentifier {
                case "GET", "POST", "PUT", "DELETE":
                    // 通常の通信では、Alamofire が String に変換したレスポンス本文を表示します。
                    if case let .success(value) = result { self.body = value }
                case "DOWNLOAD":
                    // ダウンロードでは、一度キャッシュに保存されたファイルの中身を読み込んで表示します。
                    self.body = self.downloadedBodyString()
                default:
                    break
                }
            }

            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }

        // 通常のデータ通信リクエストは responseString で本文を String として受け取ります。
        if let request = request as? DataRequest {
            request.responseString { response in
                requestComplete(response.response, response.result)
            }
        // ダウンロードリクエストも、保存後の内容を String として扱います。
        } else if let request = request as? DownloadRequest {
            request.responseString { response in
                requestComplete(response.response, response.result)
            }
        }
    }

    private func downloadedBodyString() -> String {
        // Alamofire が保存したダウンロードファイルを Caches ディレクトリから探します。
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]

        do {
            let contents = try fileManager.contentsOfDirectory(at: cachesDirectory,
                                                               includingPropertiesForKeys: nil,
                                                               options: .skipsHiddenFiles)

            if let fileURL = contents.first, let data = try? Data(contentsOf: fileURL) {
                // JSON を読み込み、見やすいインデント付きの文字列に変換します。
                let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions())
                let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)

                if let prettyString = String(data: prettyData, encoding: String.Encoding.utf8) {
                    // 表示後に一時ファイルを削除し、次回の結果と混ざらないようにします。
                    try fileManager.removeItem(at: fileURL)
                    return prettyString
                }
            }
        } catch {
            // No-op
        }

        return ""
    }
}

// MARK: - UITableViewDataSource

extension DetailViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections(rawValue: section)! {
        case .headers:
            // レスポンスヘッダーは、取得できた項目数だけ行を表示します。
            headers.count
        case .body:
            // 本文がある場合だけ 1 行表示します。
            body == nil ? 0 : 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections(rawValue: indexPath.section)! {
        case .headers:
            // ヘッダー名を左、ヘッダー値を右側の詳細テキストとして表示します。
            let cell = tableView.dequeueReusableCell(withIdentifier: "Header")!
            let field = headers.keys.sorted(by: <)[indexPath.row]
            let value = headers[field]

            cell.textLabel?.text = field
            cell.detailTextLabel?.text = value

            return cell
        case .body:
            // レスポンス本文を 1 つの大きめのセルに表示します。
            let cell = tableView.dequeueReusableCell(withIdentifier: "Body")!
            cell.textLabel?.text = body

            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension DetailViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        // ヘッダー用と本文用の 2 セクションを表示します。
        2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // 表示する行が無いセクションでは、ヘッダータイトルも出しません。
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return ""
        }

        switch Sections(rawValue: section)! {
        case .headers:
            return "Headers"
        case .body:
            return "Body"
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Sections(rawValue: indexPath.section)! {
        case .body:
            // 本文は長くなるため、通常のセルより高く表示します。
            300
        default:
            tableView.rowHeight
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        // 本文セクションのフッターに、通信にかかった秒数を表示します。
        if Sections(rawValue: section) == .body, let elapsedTime {
            let elapsedTimeText = DetailViewController.numberFormatter.string(from: elapsedTime as NSNumber) ?? "???"
            return "Elapsed Time: \(elapsedTimeText) sec"
        }

        return ""
    }
}
