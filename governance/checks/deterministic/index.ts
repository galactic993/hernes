// 司法（決定性チェック）の明示登録。新しい決定性チェックはここに 1 行追加する。
import type { DeterministicCheck } from '../../src/types'
import * as ciRunsGovernance from './ci-runs-governance'
import * as noHardcodedScreenMessages from './no-hardcoded-screen-messages'
import * as noSecretInLogs from './no-secret-in-logs'
import * as noStaticCloudCredentials from './no-static-cloud-credentials'
import * as productionRequiresApproval from './production-requires-approval'
import * as verifyGatePresent from './verify-gate-present'

export const DETERMINISTIC_CHECKS: DeterministicCheck[] = [
  noHardcodedScreenMessages,
  noSecretInLogs,
  verifyGatePresent,
  noStaticCloudCredentials,
  ciRunsGovernance,
  productionRequiresApproval,
]
