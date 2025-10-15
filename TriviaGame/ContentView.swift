import SwiftUI
import Combine

// MARK: - Data Models

struct TriviaResponse: Codable {
    let results: [TriviaQuestion]
}

struct TriviaQuestion: Codable, Identifiable {
    let id = UUID()
    let question: String
    let correct_answer: String
    let incorrect_answers: [String]
    let type: String
    let difficulty: String
    let category: String

    var allAnswers: [String] = []

    init(question: String, correct_answer: String, incorrect_answers: [String], type: String, difficulty: String, category: String) {
        self.question = question
        self.correct_answer = correct_answer
        self.incorrect_answers = incorrect_answers
        self.type = type
        self.difficulty = difficulty
        self.category = category
        self.allAnswers = (incorrect_answers + [correct_answer]).shuffled()
    }

    enum CodingKeys: String, CodingKey {
        case question, correct_answer, incorrect_answers, type, difficulty, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        question = try container.decode(String.self, forKey: .question)
        correct_answer = try container.decode(String.self, forKey: .correct_answer)
        incorrect_answers = try container.decode([String].self, forKey: .incorrect_answers)
        type = try container.decode(String.self, forKey: .type)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        category = try container.decode(String.self, forKey: .category)
        allAnswers = (incorrect_answers + [correct_answer]).shuffled()
    }
}

// MARK: - HTML Decoding

extension String {
    var safeHTMLDecoded: String {
        guard let data = self.data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributed.string
        }
        return self
    }
}

// MARK: - API Service

class TriviaService {
    func fetchTrivia(amount: Int, category: Int?, difficulty: String?, type: String?, completion: @escaping ([TriviaQuestion]) -> Void) {
        var urlString = "https://opentdb.com/api.php?amount=\(amount)"
        if let category = category { urlString += "&category=\(category)" }
        if let difficulty = difficulty { urlString += "&difficulty=\(difficulty)" }
        if let type = type { urlString += "&type=\(type)" }

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                let response = try JSONDecoder().decode(TriviaResponse.self, from: data)
                let decodedQuestions = response.results.map { q in
                    TriviaQuestion(
                        question: q.question.safeHTMLDecoded,
                        correct_answer: q.correct_answer.safeHTMLDecoded,
                        incorrect_answers: q.incorrect_answers.map { $0.safeHTMLDecoded },
                        type: q.type,
                        difficulty: q.difficulty,
                        category: q.category
                    )
                }
                DispatchQueue.main.async {
                    completion(decodedQuestions)
                }
            } catch {
                print("Decoding error: \(error)")
            }
        }.resume()
    }
}

// MARK: - Options View

struct OptionsView: View {
    @State private var numberText = "10"
    @State private var selectedCategory: Int? = nil
    @State private var difficultyValue: Double = 0.5
    @State private var selectedType: String? = "multiple"
    @State private var selectedTimer: Int = 60
    @State private var startGame = false
    @State private var showAlert = false

    let categories = [
        (9, "General Knowledge"), (11, "Movies"), (12, "Music"),
        (15, "Video Games"), (17, "Science & Nature"), (18, "Computers"),
        (23, "History"), (27, "Animals"), (31, "Japanese Anime & Manga")
    ]

    let questionTypes = [("multiple", "Multiple Choice"), ("boolean", "True / False")]

    let timerOptions = [
        ("30 seconds", 30), ("1 minute", 60), ("5 minutes", 300),
        ("10 minutes", 600), ("1 hour", 3600)
    ]

    var difficulty: String {
        switch difficultyValue {
        case ..<0.33: return "easy"
        case ..<0.66: return "medium"
        default: return "hard"
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading) {
                        Text("Number of Questions").font(.headline)
                        TextField("Enter a number (1–50)", text: $numberText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    VStack(alignment: .leading) {
                        Text("Category").font(.headline)
                        Picker("Category", selection: $selectedCategory) {
                            Text("Any").tag(nil as Int?)
                            ForEach(categories, id: \.0) { cat in
                                Text(cat.1).tag(cat.0 as Int?)
                            }
                        }.pickerStyle(MenuPickerStyle())
                    }

                    VStack(alignment: .leading) {
                        Text("Difficulty: \(difficulty.capitalized)").font(.headline)
                        Slider(value: $difficultyValue, in: 0...1)
                    }

                    VStack(alignment: .leading) {
                        Text("Question Type").font(.headline)
                        Picker("Type", selection: $selectedType) {
                            Text("Any").tag(nil as String?)
                            ForEach(questionTypes, id: \.0) { type in
                                Text(type.1).tag(type.0 as String?)
                            }
                        }.pickerStyle(MenuPickerStyle())
                    }

                    VStack(alignment: .leading) {
                        Text("Timer Duration").font(.headline)
                        Picker("Timer", selection: $selectedTimer) {
                            ForEach(timerOptions, id: \.1) { option in
                                Text(option.0).tag(option.1)
                            }
                        }.pickerStyle(MenuPickerStyle())
                    }

                    Button {
                        guard let num = Int(numberText), num >= 1, num <= 50 else {
                            showAlert = true
                            return
                        }
                        startGame = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Start Trivia")
                                .foregroundColor(.white)
                                .padding()
                            Spacer()
                        }
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Trivia Game")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Invalid Input"), message: Text("Enter valid numbers."), dismissButton: .default(Text("OK")))
            }
            .background(
                NavigationLink("", destination:
                    TriviaGameView(
                        amount: Int(numberText) ?? 10,
                        category: selectedCategory,
                        difficulty: difficulty,
                        type: selectedType,
                        timerDuration: selectedTimer
                    ),
                    isActive: $startGame
                ).hidden()
            )
        }
    }
}

// MARK: - Trivia Game View

struct TriviaGameView: View {
    let amount: Int
    let category: Int?
    let difficulty: String
    let type: String?
    let timerDuration: Int

    @State private var questions: [TriviaQuestion] = []
    @State private var selectedAnswers: [UUID: String] = [:]
    @State private var showScore = false
    @State private var timeRemaining: Int
    @State private var timerActive = true

    init(amount: Int, category: Int?, difficulty: String, type: String?, timerDuration: Int) {
        self.amount = amount
        self.category = category
        self.difficulty = difficulty
        self.type = type
        self.timerDuration = timerDuration
        _timeRemaining = State(initialValue: timerDuration)
    }

    var body: some View {
        VStack {
            if questions.isEmpty {
                ProgressView("Loading...")
                    .onAppear {
                        TriviaService().fetchTrivia(amount: amount, category: category, difficulty: difficulty, type: type) { fetched in
                            questions = fetched
                        }
                    }
            } else {
                Text("Time Remaining: \(timeRemaining)s")
                    .font(.headline)
                    .padding()

                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(questions) { question in
                            QuestionView(
                                question: question,
                                selectedAnswer: selectedAnswers[question.id],
                                showScore: showScore
                            ) { answer in
                                selectedAnswers[question.id] = answer
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Button(showScore ? "Done" : "Submit Answers") {
                    showScore = true
                    timerActive = false
                }
                .padding()
                .alert(isPresented: $showScore) {
                    let score = questions.filter { selectedAnswers[$0.id] == $0.correct_answer }.count
                    return Alert(title: Text("Your Score"),
                                 message: Text("\(score) out of \(questions.count)"),
                                 dismissButton: .default(Text("OK")))
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard timerActive else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                showScore = true
                timerActive = false
            }
        }
    }
}

// MARK: - Question View

struct QuestionView: View {
    let question: TriviaQuestion
    let selectedAnswer: String?
    let showScore: Bool
    let onSelectAnswer: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.question)
                .font(.headline)

            ForEach(question.allAnswers, id: \.self) { answer in
                Button {
                    onSelectAnswer(answer)
                } label: {
                    HStack {
                        Text(answer)
                        Spacer()
                        if showScore {
                            if answer == question.correct_answer {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if selectedAnswer == answer {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        } else if selectedAnswer == answer {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(answerBackground(answer: answer))
                    .cornerRadius(8)
                }
                .disabled(showScore)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }

    private func answerBackground(answer: String) -> Color {
        if showScore {
            if answer == question.correct_answer {
                return Color.green.opacity(0.2)
            } else if selectedAnswer == answer && answer != question.correct_answer {
                return Color.red.opacity(0.2)
            }
        } else if selectedAnswer == answer {
            return Color.blue.opacity(0.2)
        }
        return Color.gray.opacity(0.1)
    }
}

// MARK: - Entry Point

struct ContentView: View {
    var body: some View {
        OptionsView()
    }
}

#Preview {
    ContentView()
}
