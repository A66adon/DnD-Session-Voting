package ds.dnd.voting.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TimeSlotStatsDTO {
    private Long timeSlotId;
    private LocalDateTime datetime;
    private Integer voteCount;
    private Integer preferredVoteCount;
    private boolean isWinner;
}

