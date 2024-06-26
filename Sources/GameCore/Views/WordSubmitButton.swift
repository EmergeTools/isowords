import ComposableArchitecture
import SharedModels
import SwiftUI

@Reducer
public struct WordSubmitButtonFeature {
  @ObservableState
  public struct State: Equatable {
    public var isSelectedWordValid: Bool
    public let isTurnBasedMatch: Bool
    public let isYourTurn: Bool
    public var wordSubmitButton: ButtonState

    public init(
      isSelectedWordValid: Bool,
      isTurnBasedMatch: Bool,
      isYourTurn: Bool,
      wordSubmitButton: ButtonState
    ) {
      self.isSelectedWordValid = isSelectedWordValid
      self.isTurnBasedMatch = isTurnBasedMatch
      self.isYourTurn = isYourTurn
      self.wordSubmitButton = wordSubmitButton
    }
  }

  @ObservableState
  public struct ButtonState: Equatable {
    public var areReactionsOpen: Bool
    public var favoriteReactions: [Move.Reaction]
    public var isClosing: Bool
    public var isSubmitButtonPressed: Bool

    public init(
      areReactionsOpen: Bool = false,
      favoriteReactions: [Move.Reaction] = Move.Reaction.allCases,
      isClosing: Bool = false,
      isSubmitButtonPressed: Bool = false
    ) {
      self.areReactionsOpen = areReactionsOpen
      self.favoriteReactions = favoriteReactions
      self.isClosing = isClosing
      self.isSubmitButtonPressed = isSubmitButtonPressed
    }
  }

  public enum Action {
    case backgroundTapped
    case delayedSubmitButtonPressed
    case delegate(Delegate)
    case reactionButtonTapped(Move.Reaction)
    case submitButtonPressed
    case submitButtonReleased
    case submitButtonTapped

    public enum Delegate {
      case confirmSubmit(reaction: Move.Reaction?)
    }
  }

  @Dependency(\.feedbackGenerator) var feedbackGenerator
  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.audioPlayer.play) var playSound

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      enum CancelID { case submitButtonPressedDelay }

      guard state.isYourTurn
      else { return .none }

      switch action {
      case .backgroundTapped:
        state.wordSubmitButton.areReactionsOpen = false
        return .run { _ in await self.playSound(.uiSfxEmojiClose) }

      case .delayedSubmitButtonPressed:
        state.wordSubmitButton.areReactionsOpen = true
        return .run { _ in
          await self.feedbackGenerator.selectionChanged()
          await self.playSound(.uiSfxEmojiOpen)
        }

      case .delegate:
        return .none

      case let .reactionButtonTapped(reaction):
        state.wordSubmitButton.areReactionsOpen = false
        return .run { send in
          await self.feedbackGenerator.selectionChanged()
          await self.playSound(.uiSfxEmojiSend)
          await send(.delegate(.confirmSubmit(reaction: reaction)))
        }

      case .submitButtonPressed:
        guard state.isTurnBasedMatch
        else { return .none }

        if state.wordSubmitButton.areReactionsOpen {
          state.wordSubmitButton.isClosing = true
        }
        state.wordSubmitButton.areReactionsOpen = false
        state.wordSubmitButton.isSubmitButtonPressed = true

        return .run { [isClosing = state.wordSubmitButton.isClosing] send in
          await self.feedbackGenerator.selectionChanged()
          if isClosing {
            await self.playSound(.uiSfxEmojiClose)
          }
          try await self.mainQueue.sleep(for: 0.5)
          await send(.delayedSubmitButtonPressed)
        }
        .cancellable(id: CancelID.submitButtonPressedDelay, cancelInFlight: true)

      case .submitButtonReleased:
        guard state.isTurnBasedMatch
        else { return .none }

        let wasClosing = state.wordSubmitButton.isClosing
        state.wordSubmitButton.isClosing = false
        state.wordSubmitButton.isSubmitButtonPressed = false

        return .run { [areReactionsOpen = state.wordSubmitButton.areReactionsOpen] send in
          Task.cancel(id: CancelID.submitButtonPressedDelay)
          guard !wasClosing && !areReactionsOpen
          else { return }
          await send(.delegate(.confirmSubmit(reaction: nil)))
        }

      case .submitButtonTapped:
        guard !state.isTurnBasedMatch
        else { return .none }

        return .send(.delegate(.confirmSubmit(reaction: nil)))
      }
    }
  }
}

public struct WordSubmitButton: View {
  @Environment(\.deviceState) var deviceState
  let store: StoreOf<WordSubmitButtonFeature>
  @State var isTouchDown = false

  public init(store: StoreOf<WordSubmitButtonFeature>) {
    self.store = store
  }

  public var body: some View {
    ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
      if store.wordSubmitButton.areReactionsOpen {
        RadialGradient(
          gradient: Gradient(colors: [.white, Color.white.opacity(0)]),
          center: .bottom,
          startRadius: 0,
          endRadius: 350
        )
        .transition(.opacity)
      }

      VStack {
        Spacer()

        ZStack {
          ReactionsView(store: store.scope(state: \.wordSubmitButton, action: \.self))

          Button {
            store.send(.submitButtonTapped, animation: .default)
          } label: {
            Group {
              if !store.wordSubmitButton.areReactionsOpen {
                Image(systemName: "hand.thumbsup")
              } else {
                Image(systemName: "xmark")
              }
            }
            .frame(
              width: self.deviceState.idiom == .pad ? 100 : 80,
              height: self.deviceState.idiom == .pad ? 100 : 80
            )
            .background(Circle().fill(Color.adaptiveBlack))
            .foregroundColor(.adaptiveWhite)
            .opacity(store.isSelectedWordValid ? 1 : 0.5)
            .font(.system(size: self.deviceState.isPad ? 40 : 30))
            .adaptivePadding([.all], .grid(4))
            // NB: Expand the tappable radius of the button.
            .background(Color.black.opacity(0.0001))
          }
          .simultaneousGesture(
            DragGesture(minimumDistance: 0)
              .onChanged { touch in
                if !self.isTouchDown {
                  store.send(.submitButtonPressed, animation: .default)
                }
                self.isTouchDown = true
              }
              .onEnded { _ in
                store.send(.submitButtonReleased, animation: .default)
                self.isTouchDown = false
              }
          )
        }
        .padding()
      }

    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      if store.wordSubmitButton.areReactionsOpen {
        Color.isowordsBlack.opacity(0.4)
      }
    }
    .animation(.default, value: store.wordSubmitButton.areReactionsOpen)
    .onTapGesture { store.send(.backgroundTapped, animation: .default) }
  }
}

struct ReactionsView: View {
  let store: Store<WordSubmitButtonFeature.ButtonState, WordSubmitButtonFeature.Action>

  var body: some View {
    ForEach(Array(store.favoriteReactions.enumerated()), id: \.offset) { idx, reaction in
      let offset = self.offset(index: idx)

      Button {
        store.send(.reactionButtonTapped(reaction), animation: .default)
      } label: {
        Text(reaction.rawValue)
          .font(.system(size: 32))
          .padding()
      }
      .background(Color.white.opacity(0.5))
      .clipShape(Circle())
      .rotationEffect(.degrees(store.areReactionsOpen ? -360 : 0))
      .opacity(store.areReactionsOpen ? 1 : 0)
      .offset(x: offset.x, y: offset.y)
      .animation(
        .default.delay(Double(idx) / Double(store.favoriteReactions.count * 10)),
        value: store.areReactionsOpen
      )
    }
  }

  func offset(index: Int) -> CGPoint {
    let angle: CGFloat =
      CGFloat.pi / CGFloat(store.favoriteReactions.count - 1) * CGFloat(index) + .pi

    return .init(
      x: store.areReactionsOpen ? cos(angle) * 130 : 0,
      y: store.areReactionsOpen ? sin(angle) * 130 : 0
    )
  }
}

#if DEBUG
  struct WordSubmitButton_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        WordSubmitButton(
          store: .init(
            initialState: WordSubmitButtonFeature.State(
              isSelectedWordValid: true,
              isTurnBasedMatch: true,
              isYourTurn: true,
              wordSubmitButton: WordSubmitButtonFeature.ButtonState()
            )
          ) {
            WordSubmitButtonFeature()
          }
        )
        .background(Color.blue)
        .navigationBarHidden(true)
      }
      .previewDevice("iPhone 12 mini")
    }
  }
#endif
