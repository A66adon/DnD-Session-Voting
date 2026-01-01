package ds.dnd.voting.controller;

import ds.dnd.voting.dto.VoteRequestDTO;
import ds.dnd.voting.dto.WeekResultDTO;
import ds.dnd.voting.model.Vote;
import ds.dnd.voting.model.VotingWeek;
import ds.dnd.voting.services.VotingService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/voting")
@RequiredArgsConstructor
@CrossOrigin(origins = "*") // Adjust for your frontend URL
public class SVController {

    private final VotingService votingService;

    /**
     * Get the current active voting week
     */
    @GetMapping("/current-week")
    public ResponseEntity<VotingWeek> getCurrentWeek() {
        return ResponseEntity.ok(votingService.getCurrentWeek());
    }

    /**
     * Get results for the current week including votes and winner
     */
    @GetMapping("/current-results")
    public ResponseEntity<WeekResultDTO> getCurrentWeekResults() {
        return ResponseEntity.ok(votingService.getCurrentWeekResults());
    }

    /**
     * Get results for a specific week by ID
     */
    @GetMapping("/week/{weekId}/results")
    public ResponseEntity<WeekResultDTO> getWeekResults(@PathVariable Long weekId) {
        WeekResultDTO result = votingService.getWeekResults(weekId);
        if (result == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(result);
    }

    /**
     * Get all past weeks with their results (deadlines that have passed)
     */
    @GetMapping("/past-weeks")
    public ResponseEntity<List<WeekResultDTO>> getAllPastWeeks() {
        return ResponseEntity.ok(votingService.getAllPastWeeks());
    }

    /**
     * Get all weeks including current
     */
    @GetMapping("/all-weeks")
    public ResponseEntity<List<WeekResultDTO>> getAllWeeks() {
        return ResponseEntity.ok(votingService.getAllWeeks());
    }

    /**
     * Submit a vote (requires authentication)
     * Username is extracted from JWT token
     */
    @PostMapping("/vote")
    public ResponseEntity<Vote> submitVote(@RequestBody VoteRequestDTO voteRequest, HttpServletRequest request) {
        // Get authenticated username from request attribute (set by JWT filter)
        String username = (String) request.getAttribute("username");

        Vote vote = votingService.submitVote(
                username,
                voteRequest.getTimeSlotIds(),
                voteRequest.getPreferredTimeSlotId()
        );
        return ResponseEntity.ok(vote);
    }

    /**
     * Manually trigger a week reset (useful for testing/admin, requires authentication)
     */
    @PostMapping("/reset-week")
    public ResponseEntity<VotingWeek> resetWeek() {
        return ResponseEntity.ok(votingService.resetWeek());
    }
}
