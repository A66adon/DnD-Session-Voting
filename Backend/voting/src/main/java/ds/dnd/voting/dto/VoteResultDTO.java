package ds.dnd.voting.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class VoteResultDTO {
    private String voterName;
    private List<LocalDateTime> votedTimeslots;
    private LocalDateTime preferredTimeslot;
}

