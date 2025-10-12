def backward_trace(features):
  chains = []
  causes = set()
  consequences = set()
  if (features[6] == 1):
    consequences.add(6) # record consequence
    if (features[18] == 1):
      if (features[33] == 1):
        chains.append(1) # Causal chain 1
        causes.add(33) # record cause
      if (features[31] == 1):
        chains.append(2) # Causal chain 2
        causes.add(31) # record cause
  return [consequences, causes, chains]