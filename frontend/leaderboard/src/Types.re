module NewBlock = {
  type account = {publicKey: string};

  type snarkJobs = {
    prover: string,
    fee: int64,
  };

  type userCommands = {
    fromAccount: account,
    toAccount: account,
  };

  type feeTransfer = {
    fee: int64,
    recipient: string,
  };
  type transactions = {
    userCommands: array(userCommands),
    feeTransfer: array(feeTransfer),
  };

  type data = {
    creatorAccount: account,
    snarkJobs: array(snarkJobs),
    transactions,
  };

  type newBlock = {newBlock: data};

  type t = {data: newBlock};

  external unsafeJSONToNewBlock: Js.Json.t => t = "%identity";
};

module Metrics = {
  type t =
    | BlocksCreated
    | TransactionsSent
    | SnarkWorkCreated
    | SnarkFeesCollected
    | HighestSnarkFeeCollected
    | TransactionsReceivedByEcho;

  type metricRecord = {
    blocksCreated: option(int),
    transactionSent: option(int),
    snarkWorkCreated: option(int),
    snarkFeesCollected: option(int64),
    highestSnarkFeeCollected: option(int64),
    transactionsReceivedByEcho: option(int),
  };
};