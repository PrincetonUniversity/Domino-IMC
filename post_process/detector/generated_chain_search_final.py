def backward_trace(features):
  chains = []
  causes = set()
  consequences = set()
  if (features[0] == 1):
    consequences.add(0) # record consequence
    if (features[6] == 1):
      if (features[18] == 1):
        if (features[20] == 1):
          chains.append(1) # Causal chain 1
          causes.add(20) # record cause
        if (features[23] == 1 or features[24] == 1):
          if (features[28] == 1):
            chains.append(2) # Causal chain 2
            causes.add(28) # record cause
          if (features[25] == 1):
            chains.append(3) # Causal chain 3
            causes.add(25) # record cause
        if (features[31] == 1):
          chains.append(4) # Causal chain 4
          causes.add(31) # record cause
  if (features[1] == 1):
    consequences.add(1) # record consequence
    if (features[7] == 1):
      if (features[19] == 1):
        if (features[20] == 1):
          chains.append(5) # Causal chain 5
          causes.add(20) # record cause
        if (features[23] == 1 or features[24] == 1):
          if (features[27] == 1):
            chains.append(6) # Causal chain 6
            causes.add(27) # record cause
          if (features[26] == 1):
            chains.append(7) # Causal chain 7
            causes.add(26) # record cause
        if (features[30] == 1):
          chains.append(8) # Causal chain 8
          causes.add(30) # record cause
        if (features[29] == 1):
          chains.append(9) # Causal chain 9
          causes.add(29) # record cause
  if (features[12] == 1):
    consequences.add(12) # record consequence
    if (features[34] == 1 or features[35] == 1):
      if (features[18] == 1):
        if (features[20] == 1):
          chains.append(10) # Causal chain 10
          causes.add(20) # record cause
        if (features[23] == 1 or features[24] == 1):
          if (features[28] == 1):
            chains.append(11) # Causal chain 11
            causes.add(28) # record cause
          if (features[25] == 1):
            chains.append(12) # Causal chain 12
            causes.add(25) # record cause
        if (features[31] == 1):
          chains.append(13) # Causal chain 13
          causes.add(31) # record cause
      if (features[19] == 1):
        if (features[20] == 1):
          chains.append(14) # Causal chain 14
          causes.add(20) # record cause
        if (features[23] == 1 or features[24] == 1):
          if (features[27] == 1):
            chains.append(15) # Causal chain 15
            causes.add(27) # record cause
          if (features[26] == 1):
            chains.append(16) # Causal chain 16
            causes.add(26) # record cause
          if (features[29] == 1):
            chains.append(17) # Causal chain 17
            causes.add(29) # record cause
        if (features[30] == 1):
          chains.append(18) # Causal chain 18
          causes.add(30) # record cause
    if (not ( features[34] == 1 or features[35] == 1 )):
      if (features[19] == 1):
        if (features[20] == 1):
          chains.append(19) # Causal chain 19
          causes.add(20) # record cause
        if (features[23] == 1 or features[24] == 1):
          if (features[27] == 1):
            chains.append(20) # Causal chain 20
            causes.add(27) # record cause
          if (features[26] == 1):
            chains.append(21) # Causal chain 21
            causes.add(26) # record cause
        if (features[30] == 1):
          chains.append(22) # Causal chain 22
          causes.add(30) # record cause
        if (features[29] == 1):
          chains.append(23) # Causal chain 23
          causes.add(29) # record cause
  if (features[13] == 1):
    consequences.add(13) # record consequence
    if (features[34] == 1 or features[35] == 1):
      if (features[19] == 1):
        if (features[20] == 1):
          chains.append(24) # Causal chain 24
          causes.add(20) # record cause
        if (features[23] == 1 or features[24] == 1):
          if (features[27] == 1):
            chains.append(25) # Causal chain 25
            causes.add(27) # record cause
          if (features[26] == 1):
            chains.append(26) # Causal chain 26
            causes.add(26) # record cause
        if (features[30] == 1):
          chains.append(27) # Causal chain 27
          causes.add(30) # record cause
        if (features[29] == 1):
          chains.append(28) # Causal chain 28
          causes.add(29) # record cause
      if (features[18] == 1):
        if (features[20] == 1):
          chains.append(29) # Causal chain 29
          causes.add(20) # record cause
        if (features[23] == 1 or features[24] == 1):
          if (features[28] == 1):
            chains.append(30) # Causal chain 30
            causes.add(28) # record cause
          if (features[25] == 1):
            chains.append(31) # Causal chain 31
            causes.add(25) # record cause
        if (features[31] == 1):
          chains.append(32) # Causal chain 32
          causes.add(31) # record cause
  if (features[9] == 1):
    consequences.add(9) # record consequence
    if (not ( features[34] == 1 or features[35] == 1 )):
      if (features[18] == 1):
        if (features[20] == 1):
          chains.append(33) # Causal chain 33
          causes.add(20) # record cause
        if (features[23] == 1 or features[24] == 1):
          if (features[28] == 1):
            chains.append(34) # Causal chain 34
            causes.add(28) # record cause
          if (features[25] == 1):
            chains.append(35) # Causal chain 35
            causes.add(25) # record cause
        if (features[31] == 1):
          chains.append(36) # Causal chain 36
          causes.add(31) # record cause
  return [consequences, causes, chains]