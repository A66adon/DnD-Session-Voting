package ds.dnd.voting.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class WeekResultDTO {
    private Long weekId;
    private LocalDate deadline;
    private List<TimeSlotStatsDTO> timeSlots;
    private List<VoteResultDTO> votes;
    private TimeSlotStatsDTO winnerTimeSlot;
}

