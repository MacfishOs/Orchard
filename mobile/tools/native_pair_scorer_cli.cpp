/* Copyright (C) 2026 SFG545. Licensed under the Orchard-Only License (OOL-1.0), see LICENSE-OOL. */

#include <iostream>
#include <string>

#include "planner/pair_scorer.h"

int main() {
  std::string line;
  while (std::getline(std::cin, line)) {
    try {
      const auto request = orchard::planner::Json::parse(line);
      if (request.contains("analyses")) {
        std::cout << orchard::planner::SortQueue(
            request["analyses"], request.value("initial", orchard::planner::Json(nullptr))) << '\n';
      } else {
        std::cout << orchard::planner::ScorePair(
            request.at("analysis"), request.at("nextAnalysis")) << '\n';
      }
    } catch (const std::exception& error) {
      std::cerr << error.what() << '\n';
      return 1;
    }
  }
}
