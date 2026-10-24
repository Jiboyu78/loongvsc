/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

/**
 * Compatibility declarations for the optional Copilot agent-host source lane.
 *
 * Code - OSS does not ship Microsoft's native Copilot SDK or its runtime. The
 * corresponding provider is loaded only when a downstream product supplies a
 * `defaultChatAgent`; these declarations keep the shared source and tests
 * type-checkable without making the proprietary SDK an install-time dependency.
 */
declare module '@github/copilot-sdk' {
	export const CopilotClient: any;
	export const RuntimeConnection: any;
	export const approveAll: any;

	export type AssistantMessageToolRequest = any;
	export type Attachment = any;
	export type ContextTier = any;
	export type CopilotClient = any;
	export type CopilotClientOptions = any;
	export type CopilotSession = any;
	export type CurrentToolMetadata = any;
	export type CustomAgentConfig = any;
	export type ElicitationContext = any;
	export type ElicitationFieldValue = any;
	export type ElicitationResult = any;
	export type ElicitationSchema = any;
	export type ElicitationSchemaField = any;
	export type ExitPlanModeCompletedData = any;
	export type ExitPlanModeRequest = any;
	export type ExitPlanModeResult = any;
	export type GitHubTelemetryNotification = any;
	export type GitHubTokenProvider = any;
	export type JsonValue = any;
	export type MCPServerConfig = any;
	export type ManagedSettingsResolvedData = any;
	export type McpServerStatus = any;
	export type McpServersLoadedServer = any;
	export type MessageOptions = any;
	export type ModelCapabilitiesOverride = any;
	export type NamedProviderConfig = any;
	export type PermissionAssistedApproval = any;
	export type PermissionMode = any;
	export type PermissionRequest = any;
	export type PermissionRequestResult = any;
	export type PermissionResult = any;
	export type ProviderModelConfig = any;
	export type ResumeSessionConfig = any;
	export type SectionOverride = any;
	export type SessionConfig = any;
	export type SessionEvent = any;
	export type SessionEventHandler = any;
	export type SessionEventPayload = any;
	export type SessionEventType = any;
	export type SessionHooks = any;
	export type SessionMetadata = any;
	export type SessionMode = any;
	export type SkillInvokedData = any;
	export type SystemMessageConfig = any;
	export type SystemMessageSection = any;
	export type SystemNotification = any;
	export type TelemetryConfig = any;
	export type Tool = any;
	export type ToolExecutionCompleteContent = any;
	export type ToolExecutionCompleteContentShellExit = any;
	export type ToolExecutionCompleteData = any;
	export type ToolExecutionStartToolDescription = any;
	export type ToolInvocation = any;
	export type ToolResultObject = any;
	export type TypedSessionEventHandler = any;
	export type Verbosity = any;
}
