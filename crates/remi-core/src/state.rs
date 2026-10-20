use serde::{Deserialize, Serialize};

/// What Remi is shown doing for a session.
#[derive(Copy, Clone, Eq, PartialEq, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PetState {
    /// Working out what to do next.
    Thinking,
    /// Reading code.
    Viewing,
    /// Changing files.
    Writing,
    /// Writing its reply to the user.
    Replying,
    /// Blocked on the user approving something or answering a question.
    WaitingForInput,
    /// Just finished a turn; the pet fades this to idle after a few seconds.
    Proud,
    /// Between turns: what `Proud` fades into, or an explicitly interrupted turn.
    Idle,
    /// Between turns, with work the turn started in the background still running.
    ///
    /// Shown by the pet only, never written: a turn that ends that way is recorded as `Proud`
    /// with [`SessionRecord::background`](crate::record::SessionRecord::background) set, so a pet
    /// older than this state, which would reject a record carrying it, still reads the record.
    Background,
    /// The session has ended.
    Offline,
}
