def backward_trace(features):
  chains = []
  causes = set()
  consequences = set()
  if (features[0] == 1):
    consequences.add(0) # record consequence
    if (features[6] == 1):
      if (features[18] == 1):
        if (features[24] == 1):
          if (features[20] == 1):
            chains.append(1) # Causal chain 1
            causes.add(20) # record cause
          if (features[22] == 1):
            if (features[25] == 1):
              chains.append(2) # Causal chain 2
              causes.add(25) # record cause
            if (features[28] == 1):
              chains.append(3) # Causal chain 3
              causes.add(28) # record cause
        if (features[33] == 1):
          chains.append(4) # Causal chain 4
          causes.add(33) # record cause
        if (features[31] == 1):
          chains.append(5) # Causal chain 5
          causes.add(31) # record cause
  if (features[1] == 1):
    consequences.add(1) # record consequence
    if (features[7] == 1):
      if (features[19] == 1):
        if (features[23] == 1):
          if (features[20] == 1):
            chains.append(6) # Causal chain 6
            causes.add(20) # record cause
          if (features[21] == 1):
            if (features[26] == 1):
              chains.append(7) # Causal chain 7
              causes.add(26) # record cause
            if (features[27] == 1):
              chains.append(8) # Causal chain 8
              causes.add(27) # record cause
        if (features[32] == 1):
          chains.append(9) # Causal chain 9
          causes.add(32) # record cause
        if (features[30] == 1):
          chains.append(10) # Causal chain 10
          causes.add(30) # record cause
        if (features[29] == 1):
          chains.append(11) # Causal chain 11
          causes.add(29) # record cause
  return [consequences, causes, chains]