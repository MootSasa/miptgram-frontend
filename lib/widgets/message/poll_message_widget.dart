import 'package:flutter/material.dart';

/// A widget to display a poll/survey message.
class PollMessageWidget extends StatelessWidget {
  final String? question;
  final List<String> options;
  final List<int> voteCounts;
  final int? userVoteIndex; // Index of the option the user voted for, if any.

  const PollMessageWidget({
    Key? key,
    this.question,
    required this.options,
    required this.voteCounts,
    this.userVoteIndex,
  }) : super(key: key);

  /// Returns true if the lengths of [options] and [voteCounts] match.
  bool get _isValid => options.length == voteCounts.length;

  /// Returns [voteCounts] if valid, otherwise null.
  List<int>? get validVoteCounts => _isValid ? voteCounts : null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question != null && question!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                question!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ...List.generate(options.length, (index) {
            final option = options[index];
            final voteCount = validVoteCounts != null ? validVoteCounts![index] : null;
            final isUserVoted = userVoteIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // Option indicator (radio button style)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isUserVoted ? Theme.of(context).primaryColor : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: isUserVoted
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).primaryColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontWeight: isUserVoted ? FontWeight.bold : FontWeight.normal,
                        color: isUserVoted ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                  ),
                  if (voteCount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$voteCount vote${voteCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    // Show error state if vote counts are invalid
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Text(
                        'Invalid vote data',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}