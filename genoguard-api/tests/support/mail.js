// Records emails instead of sending them. Set exports.fail = true to simulate a mail outage.
exports.sent = [];
exports.fail = false;
exports.sendMatchInvite = async (to, name, code, days) => {
  if (exports.fail) throw new Error('mail down');
  exports.sent.push({ to, name, code, days });
};
exports.sendWelcome = async () => {};
exports.sendResetCode = async () => {};
