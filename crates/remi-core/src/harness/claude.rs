//! Claude Code hands every hook a JSON object on stdin. Each event adds its own fields — a
//! tool's name, its input, the permission mode — but all of them carry `session_id`, `cwd` and
//! `transcript_path`, which is nearly all we read. The exception is a tool's result
//! (`tool_response`, on `PostToolUse`), for the one thing in it that changes the pose: whether
//! the tool left work running in the background.

use std::path::PathBuf;

use serde::Deserialize;

use super::{HookInput, normalize};
use crate::record::SessionId;

/// Claude Code decides on a hook's exit code and reads stdout only from a hook that opts into
/// answering. Saying nothing is how a hook stays out of the way.
pub(super) const REPLY: Option<&str> = None;

/// The fields every Claude Code hook payload shares, and a tool's result. The rest, such as a
/// tool's input, is ignored.
#[derive(Deserialize)]
struct Payload {
    session_id: Option<SessionId>,
    cwd: Option<String>,
    transcript_path: Option<PathBuf>,
    /// Shaped by the tool, and not always an object, so taken as it comes.
    tool_response: Option<serde_json::Value>,
}

/// Whether a tool's result says the work carries on in the background. Claude Code is woken
/// with the outcome once it finishes, which is a turn of its own.
///
/// `Bash` names the task in `backgroundTaskId`, whether it was asked to run in the background
/// or was moved there while it ran. A background subagent comes back as `async_launched`.
fn launched_background(response: &serde_json::Value) -> bool {
    let task = response
        .get("backgroundTaskId")
        .and_then(serde_json::Value::as_str)
        .is_some_and(|id| !id.is_empty());
    let agent =
        response.get("status").and_then(serde_json::Value::as_str) == Some("async_launched");
    task || agent
}

pub(super) fn parse(json: &[u8]) -> Result<HookInput, serde_json::Error> {
    if normalize::is_blank(json) {
        return Ok(HookInput::default());
    }
    let payload: Payload = serde_json::from_slice(json)?;
    Ok(HookInput {
        session: payload.session_id,
        cwd: payload.cwd.as_deref().and_then(normalize::cwd_name),
        transcript: payload.transcript_path,
        launched_background: payload
            .tool_response
            .as_ref()
            .is_some_and(launched_background),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_session_cwd_and_transcript_from_a_real_payload() {
        let json = br#"{
            "session_id": "1a0e02ad-5127-41ae-b140-139fed68bc31",
            "transcript_path": "/home/u/.claude/projects/-home-u-repos-remi-desktop/1a0e02ad-5127-41ae-b140-139fed68bc31.jsonl",
            "cwd": "/home/u/repos/remi-desktop",
            "permission_mode": "default",
            "hook_event_name": "PreToolUse",
            "tool_name": "Read",
            "tool_input": {"file_path": "/home/u/repos/remi-desktop/Cargo.toml"}
        }"#;

        let input = parse(json).unwrap();

        assert_eq!(
            input.session,
            Some(SessionId::new("1a0e02ad-5127-41ae-b140-139fed68bc31").unwrap())
        );
        assert_eq!(input.cwd.as_deref(), Some("remi-desktop"));
        assert_eq!(
            input.transcript,
            Some(PathBuf::from(
                "/home/u/.claude/projects/-home-u-repos-remi-desktop/1a0e02ad-5127-41ae-b140-139fed68bc31.jsonl"
            ))
        );
    }

    #[test]
    fn a_command_run_in_the_background_is_a_launch() {
        let json = br#"{
            "session_id": "s1",
            "hook_event_name": "PostToolUse",
            "tool_name": "Bash",
            "tool_input": {"command": "sleep 30", "run_in_background": true},
            "tool_response": {"stdout": "", "stderr": "", "interrupted": false, "backgroundTaskId": "bf3k2a"}
        }"#;
        assert!(parse(json).unwrap().launched_background);
    }

    #[test]
    fn a_background_subagent_is_a_launch() {
        let json = br#"{
            "session_id": "s1",
            "hook_event_name": "PostToolUse",
            "tool_name": "Agent",
            "tool_response": {"status": "async_launched", "agentId": "a1", "description": "Run the exp"}
        }"#;
        assert!(parse(json).unwrap().launched_background);
    }

    #[test]
    fn a_tool_that_finished_is_not_a_launch() {
        for response in [
            r#"{"stdout": "ok", "stderr": "", "interrupted": false}"#,
            r#"{"status": "completed", "agentId": "a1"}"#,
            r#""plain text""#,
            r#"[{"type": "text", "text": "ok"}]"#,
        ] {
            let json = format!(r#"{{"session_id": "s1", "tool_response": {response}}}"#);
            assert!(
                !parse(json.as_bytes()).unwrap().launched_background,
                "{response}"
            );
        }
    }

    #[test]
    fn missing_fields_are_none() {
        assert_eq!(
            parse(br#"{"hook_event_name":"Stop"}"#).unwrap(),
            HookInput::default()
        );
    }

    #[test]
    fn empty_input_is_no_input() {
        assert_eq!(parse(b"").unwrap(), HookInput::default());
        assert_eq!(parse(b" \n").unwrap(), HookInput::default());
    }

    #[test]
    fn rejects_junk_and_unsafe_session_ids() {
        assert!(parse(b"not json").is_err());
        assert!(parse(br#"{"session_id":"../escape"}"#).is_err());
    }
}
