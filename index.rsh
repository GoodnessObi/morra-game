'reach 0.1';

const [isFingers, ZERO, ONE, TWO, THREE, FOUR, FIVE] = makeEnum(6);
const [
	isGuess,
	ZEROG,
	ONEG,
	TWOG,
	THREEG,
	FOURG,
	FIVEG,
	SIXG,
	SEVENG,
	EIGHTG,
	NINEG,
	TENG,
] = makeEnum(11);
const [isOutcome, B_WINS, DRAW, A_WINS] = makeEnum(3);

// game logic
const winner = (fingersA, fingersB, guessA, guessB) => {
	if (guessA == guessB) {
		const myoutcome = DRAW; //tie
		return myoutcome;
	} else {
		if (fingersA + fingersB == guessA) {
			const myoutcome = A_WINS;
			return myoutcome; // player A wins
		} else {
			if (fingersA + fingersB == guessB) {
				const myoutcome = B_WINS;
				return myoutcome; // player B wins
			} else {
				const myoutcome = DRAW; // tie
				return myoutcome;
			}
		}
	}
};

// the asserts give the forall indicators as to expected outcomes
// can work with any value, we are more concernced with all
// possible combinations of the game outcome given inputs
assert(winner(0, 4, 0, 4) == B_WINS);
assert(winner(4, 0, 4, 0) == A_WINS);
assert(winner(0, 1, 0, 4) == DRAW);
assert(winner(5, 5, 5, 5) == DRAW);

// assert for all possible combinations of inputs
forall(UInt, (fingersA) =>
	forall(UInt, (fingersB) =>
		forall(UInt, (guessA) =>
			forall(UInt, (guessB) =>
				assert(isOutcome(winner(fingersA, fingersB, guessA, guessB)))
			)
		)
	)
);

//assert for all possible hands where guesses are the same
forall(UInt, (fingersA) =>
	forall(UInt, (fingersB) =>
		forall(
			UInt,
			(
				sameGuess // this variable is local?
			) => assert(winner(fingersA, fingersB, sameGuess, sameGuess) == DRAW)
		)
	)
);

const Player = {
	...hasRandom,
	getFingers: Fun([], UInt),
	getGuess: Fun([UInt], UInt),
	// seeWinning: Fun([UInt], Null),
	seeOutcome: Fun([UInt, UInt], Null),
	informTimeout: Fun([], Null),
};

export const main = Reach.App(() => {
	const A = Participant('A', {
		...Player,
		wager: UInt,
		deadline: UInt, // time delta (blocks/rounds)
	});
	const B = Participant('B', {
		...Player,
		acceptWager: Fun([UInt], Null),
	});

	const informTimeout = () => {
		each([A, B], () => {
			interact.informTimeout();
		});
	};

	init();

	A.only(() => {
		const wager = declassify(interact.wager);
		const deadline = declassify(interact.deadline);
	});
	A.publish(wager, deadline).pay(wager);

	commit();

	B.only(() => {
		interact.acceptWager(wager);
	});
	B.pay(wager).timeout(relativeTime(deadline), () => closeTo(A, informTimeout));
	// write your program here

	var [outcome, winningNum] = [DRAW, 0];

	invariant(balance() == 2 * wager && isOutcome(outcome));
	while (outcome == DRAW) {
		commit();

		A.only(() => {
			const _fingersA = interact.getFingers();
			const _guessA = interact.getGuess(_fingersA);
			const [_fingersCommitA, _fingerSaltA] = makeCommitment(
				interact,
				_fingersA
			);
			const [_guessCommitA, _guessSaltA] = makeCommitment(interact, _guessA);
			const fingersCommitA = declassify(_fingersCommitA);
			const guessCommitA = declassify(_guessCommitA);
		});
		A.publish(fingersCommitA, guessCommitA).timeout(
			relativeTime(deadline),
			() => closeTo(B, informTimeout)
		);
		commit();

		unknowable(B, A(_fingersA, _fingerSaltA));
		unknowable(B, A(_guessA, _guessSaltA));

		B.only(() => {
			const fingersB = declassify(interact.getFingers());
			const guessB = declassify(interact.getGuess(fingersB));
		});

		B.publish(fingersB, guessB).timeout(relativeTime(deadline), () =>
			closeTo(A, informTimeout)
		);
		commit();

		A.only(() => {
			const fingerSaltA = declassify(_fingerSaltA);
			const guessSaltA = declassify(_guessSaltA);
			const fingersA = declassify(_fingersA);
			const guessA = declassify(_guessA);
		});
		A.publish(fingerSaltA, guessSaltA, fingersA, guessA).timeout(
			relativeTime(deadline),
			() => closeTo(B, informTimeout)
		);
		checkCommitment(fingersCommitA, fingerSaltA, fingersA);
		checkCommitment(guessCommitA, guessSaltA, guessA);

		[outcome, winningNum] = [
			winner(fingersA, fingersB, guessA, guessB),
			fingersA + fingersB,
		];

		continue;
	}

	assert(outcome == A_WINS || outcome == B_WINS);

	transfer(2 * wager).to(outcome == A_WINS ? A : B);

	commit();

	each([A, B], () => {
		interact.seeOutcome(outcome, winningNum);
	});

	exit();
});
